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
        address winner;
        address loser;
        uint32 winnerDamage;
        uint32 loserDamage;
    }

    /// @notice Struct to store the information on the winner and loser of the battle
    struct BattleResult {
        uint8 numRounds;
        bool isDraw;
        address winner;
        address loser;
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

    event BattleStarted(
        uint256 battleId,
        address indexed homeAddr,
        address indexed visitorAddr
    );
    event PlayerSeedCommitted(uint256 battleId, address indexed player);
    event RandomSlotNounceGenerated(
        uint256 battleId,
        address player,
        bytes32 nonce
    );
    event PlayerSeedRevealed(
        uint256 battleId,
        uint8 indexed numRounds,
        address indexed player,
        bytes32 playerSeed
    );
    event ChoiceCommitted(
        uint256 battleId,
        uint8 indexed numRounds,
        address indexed player
    );
    event ChoiceRevealed(
        uint256 battleId,
        uint8 indexed numRounds,
        address indexed player,
        uint8 levelPoint,
        Choice choice
    );
    event RoundCompleted(
        uint256 battleId,
        uint8 indexed numRounds,
        bool isDraw,
        address winner,
        address loser,
        uint32 winnerDamage,
        uint32 loserDamage
    );
    event BattleCompleted(
        uint256 battleId,
        uint8 indexed numRounds,
        bool isDraw,
        address winner,
        address loser,
        uint8 winnerCount,
        uint8 loserCount
    );

    // Events for cheater detection.
    event ExceedingLevelPointCheatDetected(
        uint256 battleId,
        address indexed cheater,
        uint8 remainingLevelPoint,
        uint8 cheaterLevelPoint
    );
    event ReusingUsedSlotCheatDetected(
        uint256 battlId,
        address indexed cheater,
        Choice targetSlot
    );

    // Events for delayer detection.
    event LatePlayerSeedCommitDetected(
        uint256 battleId,
        address indexed delayer
    );
    event LateChoiceCommitDetected(
        uint256 battleId,
        uint8 numRounds,
        address indexed delayer
    );
    event LateChoiceRevealDetected(
        uint256 battleId,
        uint8 numRounds,
        address indexed delayer
    );
    event BattleCanceled(uint256 battleId);
    event ForceInited(uint256 battleId);

    //////////////////////////////
    /// BATTLE FIELD FUNCTIONS ///
    //////////////////////////////

    function commitPlayerSeed(bytes32 commitString) external;

    function revealPlayerSeed(bytes32 playerSeed) external;

    function commitChoice(bytes32 commitString) external;

    function revealChoice(
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    ) external;

    function reportLateReveal() external;

    function reportLatePlayerSeedCommit() external;

    function reportLateChoiceCommit() external;

    function startBattle(
        address homeAddr,
        address visitorAddr,
        uint256 homeFromBlock,
        uint256 visitorFromBlock,
        uint256[4] calldata homeFixedSlots,
        uint256[4] calldata visitorFixedSlots
    ) external;

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
