// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {PLMBattleField} from "./PLMBattleField.sol";
// import {PLMBattleStarter} from "./interfaces/IPLMBattleStarter.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMBattleStarter} from "./interfaces/IPLMBattleStarter.sol";
import {IPLMMatchOrganizer} from "./interfaces/IPLMMatchOrganizer.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

contract PLMMatchOrganizer is IPLMMatchOrganizer, ReentrancyGuard, IERC165 {
    /// @notice The number of the fixed slots that one player has.
    uint8 constant FIXED_SLOTS_NUM = 4;

    /// @notice interface to the dealer of polylemma.
    IPLMDealer dealer;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice interface to the battle starter.
    IPLMBattleStarter battleStarter;

    /// @notice admin's address.
    address polylemmers;

    /// @notice BattlePlayerSeed contract's address.
    address battleChoice;

    /// @notice BattlePlayerSeed contract's address.
    address battlePlayerSeed;

    /// @notice BattleReporter contract's address.
    address battleReporter;

    // TODO: we will change the data structure to the list of all proposals and interval tree of [LB, UB].
    BattleProposal[] proposalsBoard;

    // TODO: this data structure seems to be not optimal.
    mapping(address => BattleProposal) proposals;

    /// @notice mapping tracking each player's match state.
    mapping(address => MatchState) matchStates;

    constructor(IPLMDealer _dealer, IPLMToken _token) {
        dealer = _dealer;
        token = _token;
        polylemmers = msg.sender;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != polylemmers");
        _;
    }

    modifier blockNumberIsPositive() {
        require(block.number > 0, "block.number == 0");
        _;
    }

    /// @dev battle mode is unavailable if the subscription is expired.
    modifier subscribed() {
        require(
            !dealer.subscIsExpired(msg.sender),
            "sender's subscription is expired"
        );
        _;
    }

    modifier onlyBattleContract() {
        require(msg.sender == battleChoice||msg.sender == battlePlayerSeed||msg.sender == battleReporter||msg.sender == address(battleStarter), "sender != battleContracts.");
        _;
    }

    function _createProposal(
        address home,
        BattleProposal memory proposal
    ) internal {
        proposals[home] = proposal;
        proposalsBoard.push(proposal);
    }

    function _deleteProposal(address home) internal {
        uint256 ind = 0;
        for (uint256 i; i < proposalsBoard.length; i++) {
            if (proposalsBoard[i].home == home) {
                break;
            }
            ind++;
        }

        BattleProposal memory tmpProp = proposalsBoard[ind];
        proposalsBoard[ind] = proposalsBoard[proposalsBoard.length - 1];
        proposalsBoard.pop();

        emit ProposalDeleted(home, tmpProp);
    }

    function _totalLevelOfFixedSlots(
        uint256[4] calldata fixedSlots,
        uint256 fromBlock
    ) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            totalLevel += token
                .getPriorCharacterInfo(fixedSlots[slotIdx], fromBlock)
                .level;
        }
        return totalLevel;
    }

    /////////////////////////////////
    /// MATCH ORGANIZER FUNCTIONS ///
    /////////////////////////////////

    /// @notice Function to create a new battle proposal. The proposer is assumed to be
    ///         a home player of the battle.
    /// @dev TODO: proposals are still managed by both a mapping and a struct array
    ///      it shold be impled with mappings or interval tree in the later version.
    /// @param lowerBound lower bound of the total level of the opponent player.
    ///                   its type is  uint16 because its's a sum of four characters'
    ///                   levels whose types are uint8.
    /// @param upperBound upper bound of the total level of the opponent player.
    /// @param fixedSlots tokenIds of the characters set in the fixed slots.
    ///                   Proposer has to own all of the characters when proposing and
    ///                   starting battle.
    function proposeBattle(
        uint16 lowerBound,
        uint16 upperBound,
        uint256[FIXED_SLOTS_NUM] calldata fixedSlots
    ) external nonReentrant blockNumberIsPositive subscribed {
        // Prevent the proposer from proposing twice or more.
        require(
            matchStates[msg.sender] == MatchState.NotInvolved,
            "Player can't create proposal"
        );

        for (uint256 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            // Check that the proposed fixed slots tokens are owned by the proposer.
            require(
                msg.sender == token.ownerOf(fixedSlots[slotIdx]),
                "Proposer != owner of the character."
            );

            // Check that the token was minted in the past.
            require(
                token
                    .getPriorCharacterInfo(
                        fixedSlots[slotIdx],
                        block.number - 1
                    )
                    .fromBlock < block.number,
                "Token just minted now cannot be used"
            );
        }

        // create new proposal
        BattleProposal memory proposal = BattleProposal(
            msg.sender,
            upperBound,
            lowerBound,
            _totalLevelOfFixedSlots(fixedSlots, block.number - 1),
            block.number - 1,
            fixedSlots
        );
        proposalsBoard.push(proposal);
        proposals[msg.sender] = proposal;

        emit ProposalCreated(msg.sender, proposal);

        // update status
        matchStates[msg.sender] = MatchState.Proposed;
    }

    function isProposed(address player) external view returns (bool) {
        return matchStates[player] == MatchState.Proposed;
    }

    function isInBattle(address player) external view returns (bool) {
        return matchStates[player] == MatchState.InBattle;
    }

    function isNotInvolved(address player) external view returns (bool) {
        return matchStates[player] == MatchState.NotInvolved;
    }

    /// @notice request challenge against a proposal  (visitor: The side applying for a battle against a battle proposal.)
    /// if it passes all requirements for battle beginning, it calls startBattle()
    /// @param proposer the address of home whose proposal visitor wants to request against
    /// @param fixedSlots the character party that the visitor is gonna use in battle he requests to join.
    function requestChallenge(
        address proposer,
        uint256[4] calldata fixedSlots
    ) external nonReentrant blockNumberIsPositive subscribed {
        // Check that the player designated by the address is truely a proposer.
        require(
            matchStates[proposer] == MatchState.Proposed,
            "Designated proposer isn't invalid"
        );

        // Check that the challenger is not a proposer.
        require(
            matchStates[msg.sender] == MatchState.NotInvolved,
            "Sender can't request challenge"
        );

        // Check that the proposer is subscribed.
        if (dealer.subscIsExpired(proposer)) {
            _deleteProposal(proposer);
            emit RequestRejected(msg.sender);
            return;
        }

        for (uint256 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            // Check that the fixed slots tokens are owned by the visitor.
            require(
                msg.sender == token.ownerOf(fixedSlots[slotIdx]),
                "sender != owner of the submitted character"
            );

            // Check that the token is minted in the past.
            require(
                token
                    .getPriorCharacterInfo(
                        fixedSlots[slotIdx],
                        block.number - 1
                    )
                    .fromBlock < block.number,
                "Token just minted now cannot used"
            );
        }

        // Check that the home's fixed slots are still owned by the home.
        for (uint256 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            if (
                proposer !=
                token.ownerOf(proposals[proposer].fixedSlots[slotIdx])
            ) {
                // Otherwise, delete the proposal.
                _deleteProposal(proposer);
                matchStates[proposer] = MatchState.NotInvolved;
                emit NoLongerOwnedByProposer(proposer, fixedSlots[slotIdx]);
                return;
            }
        }

        BattleProposal memory proposal = proposals[proposer];
        uint16 visitorTotalLevel = _totalLevelOfFixedSlots(
            fixedSlots,
            block.number - 1
        );

        // Check that the visitor's fixed slots satisfy the condition written in
        // the proposal.
        require(
            visitorTotalLevel >= proposal.lowerBound &&
                visitorTotalLevel <= proposal.upperBound,
            "Violate level condition"
        );

        // pay stamina
        /// @dev if players do not have enough stamina, this function will revert the excutions.
        dealer.consumeStaminaForBattle(proposer);
        dealer.consumeStaminaForBattle(msg.sender);

        // start battle.
        battleStarter.startBattle(
            proposer,
            msg.sender,
            proposals[proposer].fromBlock,
            block.number - 1,
            proposal.fixedSlots,
            fixedSlots
        );

        // udapte Status
        matchStates[proposer] = MatchState.InBattle;
        matchStates[msg.sender] = MatchState.InBattle;

        // delete proposal
        _deleteProposal(proposer);
    }

    /// @dev This function is called from battle field contract when settling the battle.
    function resetMatchStates(
        address home,
        address visitor
    ) external onlyBattleContract {
        matchStates[home] = MatchState.NotInvolved;
        matchStates[visitor] = MatchState.NotInvolved;
    }

    /// @dev This function is called from battle field contract when canceling the battle
    ///      because of cheater/lazy player detection.
    function cancelProposal() external {
        _deleteProposal(msg.sender);
        matchStates[msg.sender] = MatchState.NotInvolved;
    }

    ////////////////////////
    ///      GETTER      ///
    ////////////////////////

    function getProposalList() external view returns (BattleProposal[] memory) {
        return proposalsBoard;
    }

    function getMatchState(address player) external view returns (MatchState) {
        return matchStates[player];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPLMMatchOrganizer).interfaceId;
    }

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    /// @notice Function to set battle field contract's address as interface inside
    ///         this contract.
    /// @dev This contract and BattleField contract is referenced each other.
    ///      This is the reason why we have to prepare this function.
    ///      Given contract address, this function checks that the contract supports
    ///      IPLMBattleField interface. If so, set the address as interface.
    /// @param _battleChoice: the contract address of PLMBattleChoice contract.
    /// @param _battlePlayerSeed: the contract address of PLMBattlePlayerSeed contract.
    /// @param _battleReporter: the contract address of PLMBattleReporter contract.
    /// @param _battleStarter: the contract address of PLMBattleStarter contract.
    function setPLMBattleContracts(address _battleChoice,  address _battlePlayerSeed ,address _battleReporter, address _battleStarter) external onlyPolylemmers {
        require(
            IERC165(_battleStarter).supportsInterface(
                type(IPLMBattleStarter).interfaceId
            ),
            "Given contract doesn't support IPLMBattleStarter"
        );
        battleStarter = IPLMBattleStarter(_battleStarter);
        battleChoice = _battleChoice;
        battlePlayerSeed = _battlePlayerSeed;
        battleReporter = _battleReporter;
    }

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////

    // FIXME: remove this function after demo.
    function forceResetMatchState(address player) public {
        matchStates[player] = MatchState.NotInvolved;
    }
}
