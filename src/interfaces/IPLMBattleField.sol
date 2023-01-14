import {IPLMToken} from "./IPLMToken.sol";
import {IPLMMatchOrganizer} from "../interfaces/IPLMMatchOrganizer.sol";

interface IPLMBattleField {
    ////////////////////////
    ///      ENUMS       ///
    ////////////////////////

    /// @notice Enum to represent battle's state.
    enum BattleState {
        NotStarted, // 0
        Standby, // 1
        InRound, // 2
        RoundSettled, // 3
        Settled, // 4
        Canceled // 5
    }

    /// @notice Random slots' state
    enum RandomSlotState {
        NotSet, // 0
        Committed, // 1
        Revealed // 2
    }

    /// @notice Enum to represent players' identities.
    enum PlayerId {
        Home, // 0
        Visitor // 1
    }

    /// @notice Players' states in each round.
    enum PlayerState {
        Standby, // 0
        Committed, // 1
        Revealed // 2
    }

    /// @notice Enum to represent player's choice of the character fighting in the next round.
    enum Choice {
        Fixed1, // 0
        Fixed2, // 1
        Fixed3, // 2
        Fixed4, // 3
        Random, // 4
        Hidden // 5
    }

    ////////////////////////
    ///      STRUCTS     ///
    ////////////////////////

    /// @notice Struct to store the information of the random slot.
    struct RandomSlot {
        uint8 level;
        bytes32 nonce;
        uint8 usedRound;
        RandomSlotState state;
    }

    /// @notice Struct to store the information on the winner and loser of each round
    struct RoundResult {
        bool isDraw;
        PlayerId winner;
        PlayerId loser;
        uint32 winnerDamage;
        uint32 loserDamage;
    }

    /// @notice Struct to store the information on the winner and loser of the battle
    struct BattleResult {
        uint8 numRounds;
        bool isDraw;
        PlayerId winner;
        PlayerId loser;
        uint8 winnerCount;
        uint8 loserCount;
    }

    /// @notice Struct to store player's infomation.
    struct PlayerInfo {
        address addr;
        uint256 fromBlock;
        uint256[4] fixedSlots;
        uint8[4] fixedSlotsUsedRounds;
        RandomSlot randomSlot;
        PlayerState state;
        uint8 winCount;
        uint8 maxLevelPoint;
        uint8 remainingLevelPoint;
    }

    /// @notice Struct to represent the commitment of the choice.
    struct ChoiceCommit {
        bytes32 commitString;
        uint8 levelPoint;
        Choice choice;
    }

    /// @notice Struct to represent the commitment of the player seed.
    struct PlayerSeedCommit {
        bytes32 commitString;
        bytes32 playerSeed;
    }

    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event BattleStarted(address indexed homeAddr, address indexed visitorAddr);
    event PlayerSeedCommitted(PlayerId indexed playerId);
    event RandomSlotNounceGenerated(PlayerId playerId, bytes32 nonce);
    event PlayerSeedRevealed(
        uint8 indexed numRounds,
        PlayerId indexed playerId,
        bytes32 playerSeed
    );
    event ChoiceCommitted(uint8 indexed numRounds, PlayerId indexed playerId);
    event ChoiceRevealed(
        uint8 indexed numRounds,
        PlayerId indexed playerId,
        uint8 levelPoint,
        Choice choice
    );
    event RoundCompleted(
        uint8 indexed numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint32 winnerDamage,
        uint32 loserDamage
    );
    event BattleCompleted(
        uint8 indexed numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint8 winnerCount,
        uint8 loserCount
    );

    // Events for cheater detection.
    event ExceedingLevelPointCheatDetected(
        PlayerId indexed cheater,
        uint8 remainingLevelPoint,
        uint8 cheaterLevelPoint
    );
    event ReusingUsedSlotCheatDetected(
        PlayerId indexed cheater,
        Choice targetSlot
    );

    // Events for delayer detection.
    event LatePlayerSeedCommitDetected(PlayerId indexed delayer);
    event LateChoiceCommitDetected(uint8 numRounds, PlayerId indexed delayer);
    event LateChoiceRevealDetected(uint8 numRounds, PlayerId indexed delayer);
    event BattleCanceled();

    //////////////////////////////
    /// BATTLE FIELD FUNCTIONS ///
    //////////////////////////////

    function commitPlayerSeed(PlayerId playerId, bytes32 commitString) external;

    function revealPlayerSeed(PlayerId playerId, bytes32 playerSeed) external;

    function commitChoice(PlayerId playerId, bytes32 commitString) external;

    function revealChoice(
        PlayerId playerId,
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    ) external;

    function reportLateReveal(PlayerId playerId) external;

    function startBattle(
        address homeAddr,
        address visitorAddr,
        uint256 homeFromBlock,
        uint256 visitorFromBlock,
        uint256[4] calldata homeFixedSlots,
        uint256[4] calldata visitorFixedSlots
    ) external;

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getBattleState() external view returns (BattleState);

    function getPlayerState(PlayerId playerId)
        external
        view
        returns (PlayerState);

    function getRemainingLevelPoint(PlayerId playerId)
        external
        view
        returns (uint256);

    function getNonce(PlayerId playerId) external view returns (bytes32);

    function getFixedSlotCharInfo(PlayerId playerId)
        external
        view
        returns (IPLMToken.CharacterInfo[4] memory);

    function getVirtualRandomSlotCharInfo(PlayerId playerId, uint256 tokenId)
        external
        view
        returns (IPLMToken.CharacterInfo memory);

    function getRandomSlotCharInfo(PlayerId playerId)
        external
        view
        returns (IPLMToken.CharacterInfo memory);

    function getCharsUsedRounds(PlayerId playerId)
        external
        view
        returns (uint8[5] memory);

    function getPlayerIdFromAddr(address playerAddr)
        external
        view
        returns (PlayerId);

    function getBondLevelAtBattleStart(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32);

    function getTotalSupplyAtFromBlock(PlayerId playerId)
        external
        view
        returns (uint256);

    function getCurrentRound() external view returns (uint8);

    function getMaxLevelPoint(PlayerId playerId) external view returns (uint8);

    function getRoundResults() external view returns (RoundResult[] memory);

    function getBattleResult() external view returns (BattleResult memory);

    function getRandomSlotState(PlayerId playerId)
        external
        view
        returns (RandomSlotState);

    function getRandomSlotLevel(PlayerId playerId)
        external
        view
        returns (uint8);

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    function setPLMMatchOrganizer(address _matchOrganizer) external;

    //////////////////////////
    /// FUNCTIONS FOR DEMO ///
    //////////////////////////

    // FIXME: remove this function after demo.
    function forceInitBattle() external;
}
