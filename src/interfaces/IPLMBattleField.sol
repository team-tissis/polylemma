interface IPLMBattleField {
    /// @notice Enum to represent battle's state.
    enum BattleState {
        Preparing, // 0
        RoundStarted, // 1
        RoundSettled // 2
    }

    /// @notice Struct to store player's infomation.
    struct PlayerInfo {
        address addr;
        uint256[4] fixedSlots;
        bool[4] slotsUsed;
        RandomSlot randomSlot;
        PlayerState state;
        uint8 winCount;
    }

    /// @notice Struct to store the information of the random slot.
    struct RandomSlot {
        uint8 level;
        bytes32 nonce;
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
        RoundStarted, // 0
        Committed, // 1
        Revealed, // 2
        RoundSettled // 3
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

    /// @notice Struct to represent the commitment of the choice.
    struct ChoiceCommitment {
        bytes32 commitString;
        Choice choice;
    }

    /// @notice Struct to represent the commitment of the player seed.
    struct PlayerSeedCommitment {
        bytes32 commitString;
        bytes32 playerSeed;
    }

    event PlayerSeedCommitted(PlayerId playerId);
    event RandomSlotNounceGenerated(PlayerId playerId, bytes32 nonce);
    event PlayerSeedRevealed(PlayerId playerId, bytes32 playerSeed);
    event ChoiceCommitted(uint8 numRounds, PlayerId playerId);
    event ChoiceRevealed(uint8 numRounds, PlayerId playerId, Choice choice);
    event RoundResult(
        uint8 numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint8 winnerDamage,
        uint8 loserDamage
    );
    event BattleResult(
        uint8 numRounds,
        bool isDraw,
        PlayerId winner,
        PlayerId loser,
        uint8 winCount,
        uint8 loseCount
    );

    function commitPlayerSeed(PlayerId playerId, bytes32 commitString) external;

    function revealPlayerSeed(
        PlayerId playerId,
        bytes32 playerSeed,
        bytes32 bindingFactor
    ) external;

    function commitChoice(PlayerId playerId, bytes32 commitString) external;

    function revealChoice(
        PlayerId playerId,
        Choice choice,
        bytes32 bindingFactor
    ) external;
}
