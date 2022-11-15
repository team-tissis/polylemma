import {IPLMToken} from "./IPLMToken.sol";
import {IPLMMatchOrganizer} from "../interfaces/IPLMMatchOrganizer.sol";

interface IPLMBattleField {
    /// @notice Enum to represent battle's state.
    enum BattleState {
        Settled, // 0
        Preparing, // 1
        RoundStarted, // 2
        RoundSettled // 3
    }
    /// @notice Struct to store the information of the random slot.
    struct RandomSlot {
        uint8 level;
        bytes32 nonce;
        bool nonceSet;
        bool used;
        RandomSlotState state;
    }

    /// @notice Random slots' state
    enum RandomSlotState {
        NotSet, // 0
        Committed, // 1
        Revealed // 2
    }

    /// @notice Enum to represent players' identities.
    enum PlayerId {
        Alice, // 0
        Bob // 1
    }

    /// @notice Players' states in each round.
    enum PlayerState {
        Preparing, // 0
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
        Secret // 5
    }

    /// @notice Struct to store player's infomation.
    struct PlayerInfo {
        address addr;
        uint256 startBlockNum;
        uint256[4] fixedSlots;
        bool[4] slotsUsed;
        RandomSlot randomSlot;
        PlayerState state;
        uint8 winCount;
        uint8 remainingLevelPoint;
    }

    /// @notice Struct to represent the commitment of the choice.
    struct ChoiceCommitment {
        bytes32 commitString;
        uint8 levelPoint;
        Choice choice;
    }

    /// @notice Struct to represent the commitment of the player seed.
    struct PlayerSeedCommitment {
        bytes32 commitString;
        bytes32 playerSeed;
    }

    // Alice = proposer, Bob = requester.
    event BattleStarted(address aliceAddr, address bobAddr);
    event PlayerSeedCommitted(PlayerId playerId);
    event RandomSlotNounceGenerated(PlayerId playerId, bytes32 nonce);
    event PlayerSeedRevealed(
        uint8 numRounds,
        PlayerId playerId,
        bytes32 playerSeed
    );
    event ChoiceCommitted(uint8 numRounds, PlayerId playerId);
    event ChoiceRevealed(
        uint8 numRounds,
        PlayerId playerId,
        uint8 levelPoint,
        Choice choice
    );
    event RoundResult(
        uint8 numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint32 winnerDamage,
        uint32 loserDamage
    );
    event BattleResult(
        uint8 numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint8 winCount,
        uint8 loseCount
    );

    // Events for cheater detection.
    event ExceedingLevelPointCheatDetected(
        PlayerId cheater,
        uint8 remainingLevelPoint,
        uint8 cheaterLevelPoint
    );
    event ReusingUsedSlotCheatDetected(PlayerId cheater, Choice targetSlot);

    // Events for lazy player detection.
    event TimeOutAtPlayerSeedCommitDetected(PlayerId lazyPlayer);
    event TimeOutAtChoiceCommitDetected(uint8 numRounds, PlayerId lazyPlayer);
    event TimeOutAtChoiceRevealDetected(uint8 numRounds, PlayerId lazyPlayer);
    event BattleCanceled(PlayerId cause);

    function commitPlayerSeed(PlayerId playerId, bytes32 commitString) external;

    function revealPlayerSeed(PlayerId playerId, bytes32 playerSeed) external;

    function commitChoice(PlayerId playerId, bytes32 commitString) external;

    function revealChoice(
        PlayerId playerId,
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    ) external;

    function reportLazyRevealment(PlayerId playerId) external;

    function startBattle(
        address aliceAddr,
        address bobAddr,
        uint256 aliceBlockNum,
        uint256 bobBlockNum,
        uint256[4] calldata aliceFixedSlots,
        uint256[4] calldata bobFixedSlots
    ) external;

    ////////////////////////
    ///      GETTER      ///
    ////////////////////////

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

    function getPlayerIdFromAddress(address playerAddr)
        external
        view
        returns (PlayerId);

    function getBondLevelAtBattleStart(uint8 level, uint256 startBlock)
        external
        view
        returns (uint32);

    function getTotalSupplyAtBattleStart(PlayerId playerId)
        external
        view
        returns (uint256);

    function getRemainingLevelPoint(PlayerId playerId)
        external
        view
        returns (uint8);

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    function setIPLMMatchOrganizer(
        IPLMMatchOrganizer _mo,
        address _matchOrganizer
    ) external;

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////
    // FIXME: remove this function after demo.
    function forceInitBattle() external;
}
