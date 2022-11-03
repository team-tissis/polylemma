// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMBattleField} from "./subcontracts/PLMBattleField.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "./interfaces/IPLMMatchOrganizer.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PLMMatchOrganizer is
    ReentrancyGuard,
    PLMBattleField,
    IPLMMatchOrganizer
{
    // TODO: we will change the data structure to the list of all proposals and interval tree of [LB, UB].
    BattleProposal[] proposalsBoard;
    mapping(address => BattleProposal) address2Proposal;
    mapping(address => MatchState) matchStates;

    constructor(IPLMDealer _dealer, IPLMToken _token) {
        dealer = _dealer;
        token = _token;
    }

    modifier blockNumIsNotZero() {
        require(block.number != 0, "block number is zero.");
        _;
    }
    modifier subscribed() {
        require(
            !dealer.subscIsExpired(msg.sender),
            "sender's subscription is expired."
        );
        _;
    }

    /// @notice A Battle proposer creates battle proposal and the proposer state is updated
    /// @dev TODO: proposals are still managed by both a mapping and a struct array, it shold be impled with interval tree
    /// @param lowerBound lower bound of the  opponent level that the proposer wanna fight. it is uint16 because it is sum of four characters' level (uint8)
    /// @param upperBound upper bound of the opponent level
    /// @param fixedSlotsOfProposer the character party that the proposer is gonna use in battle he proposes.
    function proposeBattle(
        uint16 lowerBound,
        uint16 upperBound,
        uint256[FIXEDSLOT_NUM] calldata fixedSlotsOfProposer
    ) external nonReentrant blockNumIsNotZero subscribed {
        require(
            matchStates[msg.sender] == MatchState.NonProposal,
            "sender is proposing, or in battle."
        );
        for (uint256 i = 0; i < FIXEDSLOT_NUM; i++) {
            require(
                msg.sender == token.ownerOf(fixedSlotsOfProposer[i]),
                "proposed characters contains not sender's tokenId"
            );
        }
        // create new proposal
        BattleProposal memory prop = BattleProposal(
            msg.sender,
            upperBound,
            lowerBound,
            _getTotalLevelOfFixedSlots(fixedSlotsOfProposer, block.number - 1),
            block.number - 1,
            fixedSlotsOfProposer
        );
        proposalsBoard.push(prop);
        address2Proposal[msg.sender] = prop;

        emit ProposalCreated(msg.sender, prop);

        // update status
        matchStates[msg.sender] = MatchState.Proposal;
    }

    function getProposalList() public view returns (BattleProposal[] memory) {
        //TODO gilterling
        return proposalsBoard;
    }

    function getMatchState(address player) public view returns (MatchState) {
        return matchStates[player];
    }

    function isInProposal(address player) public view returns (bool) {
        return matchStates[player] == MatchState.Proposal;
    }

    function isInBattle(address player) public view returns (bool) {
        return matchStates[player] == MatchState.InBattle;
    }

    function isNonProposal(address player) public view returns (bool) {
        return matchStates[player] == MatchState.NonProposal;
    }

    /// @notice request challenge against a proposal  (challenger: The side applying for a battle against a battle proposal.)
    /// if it passes all requirements for battle beginning, it calls startBattle()
    /// @param proposer the address of proposer whose proposal challenger wants to request against
    /// @param fixedSlotsOfChallenger the character party that the challenger is gonna use in battle he requests to join.
    function requestChallenge(
        address proposer,
        uint256[4] calldata fixedSlotsOfChallenger
    ) external nonReentrant blockNumIsNotZero subscribed {
        require(
            matchStates[proposer] == MatchState.Proposal,
            "called address is not in proposal"
        );
        require(
            matchStates[msg.sender] == MatchState.NonProposal,
            "sender is in Battle or proposing."
        );

        if (dealer.subscIsExpired(proposer)) {
            _deleteProposal(proposer);
            emit RequestRejected(msg.sender);
            return;
        }

        for (uint256 i = 0; i < FIXEDSLOT_NUM; i++) {
            require(
                msg.sender == token.ownerOf(fixedSlotsOfChallenger[i]),
                "submitted characters contains not sender's tokenId"
            );
            require(
                token
                    .getPriorCharacterInfo(
                        fixedSlotsOfChallenger[i],
                        block.number - 1
                    )
                    .fromBlock < block.number,
                "token just minted cannot used in battle."
            );
        }
        for (uint256 i = 0; i < FIXEDSLOT_NUM; i++) {
            if (
                proposer !=
                token.ownerOf(address2Proposal[proposer].fixedSlots[i])
            ) {
                _deleteProposal(proposer);
                matchStates[proposer] = MatchState.NonProposal;
                emit ProposerIsNotOwner(
                    "submitted characters contains not sender's tokenId"
                );
                return;
            }
        }

        BattleProposal memory proposal = address2Proposal[proposer];
        uint16 challengerTotalLevel = _getTotalLevelOfFixedSlots(
            fixedSlotsOfChallenger,
            block.number - 1
        );

        require(
            challengerTotalLevel >= proposal.lowerBound &&
                challengerTotalLevel <= proposal.upperBound,
            "not satisfy the level condition."
        );

        startBattle(
            proposer,
            msg.sender,
            address2Proposal[proposer].startBlockNum,
            block.number - 1,
            proposal.fixedSlots,
            fixedSlotsOfChallenger
        );

        // udapte Status
        matchStates[proposer] = MatchState.InBattle;
        matchStates[msg.sender] = MatchState.InBattle;
        // delete proposal
        _deleteProposal(proposer);
    }

    // TODO: not tested yet
    function _cancelBattle() internal override(PLMBattleField) {
        super._cancelBattle();
        matchStates[playerInfoTable[PlayerId.Alice].addr] = MatchState
            .NonProposal;
        matchStates[playerInfoTable[PlayerId.Bob].addr] = MatchState
            .NonProposal;
    }

    // TODO: not tested yet
    function _settleBattle() internal override(PLMBattleField) {
        super._settleBattle();
        matchStates[playerInfoTable[PlayerId.Alice].addr] = MatchState
            .NonProposal;
        matchStates[playerInfoTable[PlayerId.Bob].addr] = MatchState
            .NonProposal;
    }

    function cancelProposal() external {
        _deleteProposal(msg.sender);
        matchStates[msg.sender] = MatchState.NonProposal;
    }

    function _createProposal(address proposer, BattleProposal memory proposal)
        internal
    {
        address2Proposal[proposer] = proposal;
        proposalsBoard.push(proposal);
    }

    function _deleteProposal(address proposer) internal {
        uint256 ind = 0;
        for (uint256 i; i < proposalsBoard.length; i++) {
            if (proposalsBoard[i].proposer == proposer) {
                break;
            }
            ind++;
        }

        BattleProposal memory tmpProp = proposalsBoard[ind];
        proposalsBoard[ind] = proposalsBoard[proposalsBoard.length - 1];
        proposalsBoard.pop();

        emit ProposalDeleted(proposer, tmpProp);
    }

    function _getTotalLevelOfFixedSlots(
        uint256[4] calldata party,
        uint256 blockNum
    ) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 i = 0; i < 4; i++) {
            totalLevel += token.getPriorCharacterInfo(party[i], blockNum).level;
        }
        return totalLevel;
    }
}
