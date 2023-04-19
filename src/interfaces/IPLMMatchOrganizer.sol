import {IPLMBattleField} from "./IPLMBattleField.sol";

interface IPLMMatchOrganizer {
    ////////////////////////
    ///      ENUMS       ///
    ////////////////////////

    enum MatchState {
        NotInvolved, // 0
        Proposed, // 1
        InBattle // 2
    }

    ////////////////////////
    ///      STRUCTS     ///
    ////////////////////////

    struct BattleProposal {
        address home;
        uint16 upperBound;
        uint16 lowerBound;
        uint16 totalLevel;
        uint256 fromBlock;
        uint256[4] fixedSlots;
    }

    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event RequestRejected(address indexed challenger);
    event ProposalCreated(address indexed proposer, BattleProposal proposal);
    event ProposalDeleted(address indexed proposer, BattleProposal proposal);
    event NoLongerOwnedByProposer(address indexed proposer, uint256 tokenId);

    /////////////////////////////////
    /// MATCH ORGANIZER FUNCTIONS ///
    /////////////////////////////////

    function proposeBattle(
        uint16 lowerBound,
        uint16 upperBound,
        uint256[4] calldata fixedSlots
    ) external;

    function isProposed(address player) external view returns (bool);

    function isInBattle(address player) external view returns (bool);

    function isNotInvolved(address player) external view returns (bool);

    function requestChallenge(
        address proposer,
        uint256[4] calldata fixedSlots
    ) external;

    function resetMatchStates(address home, address visitor) external;

    function cancelProposal() external;

    /////////////////////////
    ///      GETTERS      ///
    /////////////////////////

    function getProposalList() external view returns (BattleProposal[] memory);

    function getMatchState(address player) external view returns (MatchState);

    /////////////////////////
    ///      SETTERS      ///
    /////////////////////////

    function setPLMBattleContracts(address _battleChoice,  address _battlePlayerSeed, address _battleReporter, address _battleStarter) external;


    //////////////////////////
    /// FUNCTIONS FOR DEMO ///
    //////////////////////////

    // FIXME: remove this function after demo.
    function forceResetMatchState(address player) external;
}
