import {IPLMBattleField} from "./IPLMBattleField.sol";

interface IPLMMatchOrganizer {
    enum MatchState {
        NonProposal,
        Proposal,
        InBattle
    }

    struct BattleProposal {
        address proposer;
        uint16 upperBound;
        uint16 lowerBound;
        uint16 totalLevel;
        uint256 startBlockNum;
        uint256[4] fixedSlots;
    }

    event RequestRejected(address indexed challenfer);

    event ProposalCreated(address indexed proposer, BattleProposal createdProp);

    event ProposalDeleted(address indexed proposer, BattleProposal deletedProp);

    event ProposerIsNotOwner(string reason);

    function proposeBattle(
        uint16 lowerBound,
        uint16 upperBound,
        uint256[4] calldata fixedSlotsOfProposer
    ) external;

    function isInProposal(address player) external view returns (bool);

    function isInBattle(address player) external view returns (bool);

    function isNonProposal(address player) external view returns (bool);

    function requestChallenge(
        address proposer,
        uint256[4] calldata fixedSlotsOfChallenger
    ) external;

    function updateProposalState2NonProposal(
        address proposer,
        address challenger
    ) external;

    function cancelProposal() external;

    ////////////////////////
    ///      GETTER      ///
    ////////////////////////

    function getProposalList() external view returns (BattleProposal[] memory);

    function getMatchState(address player) external view returns (MatchState);

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    function setIPLMBattleField(IPLMBattleField _bf, address _battleField)
        external;

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////
    // FIXME: remove this function after demo.
    function setNonProposal(address player) external;
}
