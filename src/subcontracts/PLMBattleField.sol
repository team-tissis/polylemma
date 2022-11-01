// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "../lib/PLMSeeder.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "../interfaces/IPLMToken.sol";
import {IPLMDealer} from "../interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "../interfaces/IPLMBattleField.sol";

contract PLMBattleField is IPLMBattleField, ReentrancyGuard {
    /// @notice The number of winning needed to win the match.
    uint8 constant WIN_COUNT = 3;

    /// @notice The number of the maximum round.
    uint8 constant MAX_ROUNDS = 5;

    /// @notice The number of the fixed slots that one player has.
    uint8 constant FIXEDSLOT_NUM = 4;

    /// @notice The number of blocks generated per day.
    uint256 constant DAILY_BLOCK_NUM = 43200;

    /// @notice The length of the dates to ban cheater account.
    uint256 constant BAN_DATE_LENGTH_FOR_CHEATER = 10;

    /// @notice The length of the dates to ban lazy account.
    uint256 constant BAN_DATE_LENGTH_FOR_LAZY_ACCOUNT = 2;

    /// @notice The limit of playerSeed commitment for each player. About 30 seconds.
    uint256 constant PLAYER_SEED_COMMIT_TIME_LIMIT = 15;

    /// @notice The limit of commitment for each player. About 30 seconds.
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 15;

    /// @notice The limit of revealment for each player. About 30 seconds.
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 15;

    /// @notice interface to the dealer of polylemma.
    IPLMDealer dealer;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice state of the battle.
    BattleState battleState;

    /// @notice number of rounds. (< MAX_ROUNDS)
    uint8 numRounds;

    /// @notice block number when playerSeed commitment starts.
    uint256 playerSeedCommitStartPoint;

    /// @notice block number log when choice committment starts for all rounds.
    mapping(uint8 => uint256) choiceCommitStartPoints;

    /// @notice block number log when choice revealment starts for all rounds.
    mapping(uint8 => uint256) choiceRevealStartPoints;

    /// @notice commitment log for all rounds.
    /// @dev The key is numRounds.
    mapping(uint8 => mapping(PlayerId => ChoiceCommitment)) choiceCommitLog;

    /// @notice commitment log for player seed.
    mapping(PlayerId => PlayerSeedCommitment) playerSeedCommitLog;

    /// @notice players' information
    mapping(PlayerId => PlayerInfo) playerInfoTable;

    /// @notice Check whether the caller of the function is the valid account.
    /// @param playerId: The player's identifier.
    modifier onlyPlayerOfIdx(PlayerId playerId) {
        require(
            playerId == PlayerId.Alice || playerId == PlayerId.Bob,
            "Invalid playerId."
        );
        require(
            msg.sender == playerInfoTable[playerId].addr,
            "The caller player is not the valid account."
        );
        _;
    }

    /// @notice Check that the battle round has already started.
    modifier roundStarted() {
        require(
            _getRandomSlotState(PlayerId.Alice) != RandomSlotState.NotSet &&
                _getRandomSlotState(PlayerId.Bob) != RandomSlotState.NotSet,
            "random slots haven't set yet."
        );
        require(
            battleState == BattleState.RoundStarted,
            "battle round hasn't started yet."
        );
        _;
    }

    /// @notice Check that the random slot of the player designated by playerId
    ///         has already been committed, the choice of that player in this
    ///         round is randomSlot, and it has already been revealed.
    modifier readyForPlayerSeedRevealment(PlayerId playerId) {
        require(
            _getRandomSlotState(playerId) == RandomSlotState.Committed,
            "The commit of random slot has already been revealed."
        );
        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;
        require(
            _getPlayerState(playerId) == PlayerState.Committed &&
                _getPlayerState(enemyId) == PlayerState.Committed,
            "Alice or Bob has not committed his/her choice yet."
        );
        _;
    }

    /// @notice Check that both players have already committed in this round.
    /// @param playerId: The player's identifier.
    modifier readyForChoiceRevealment(PlayerId playerId) {
        require(
            _getPlayerState(playerId) == PlayerState.Committed,
            "The player hasn't committed the choice in this round yet."
        );
        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;
        PlayerState enemyState = _getPlayerState(enemyId);
        require(
            enemyState == PlayerState.Committed ||
                enemyState == PlayerState.Revealed,
            "The enemy player hasn't committed the choice in this round yet."
        );
        _;
    }

    /// @notice Check that both players have already revealed in this round.
    modifier readyForRoundSettlement() {
        require(
            _getPlayerState(PlayerId.Alice) == PlayerState.Revealed &&
                _getPlayerState(PlayerId.Bob) == PlayerState.Revealed,
            "Both palyes have to reveal their choices before executing the battle."
        );
        _;
    }

    /// @notice Check that this battle is ready for settlement.
    modifier readyForBattleSettlement() {
        require(
            battleState == BattleState.RoundSettled,
            "This battle is ongoing."
        );
        _;
    }

    /// @notice Check that this battle is ready for start.
    modifier readyForBattleStart() {
        require(
            battleState == BattleState.Settled,
            "Battle is not ready for start."
        );
        _;
    }

    /// @notice Commit the player's seed to generate the tokenId for random slot.
    /// @param playerId: the identifier of the player. Alice or Bob.
    /// @param commitString: commitment string calculated by the player designated by playerId
    ///                      as keccak256(abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor)).
    function commitPlayerSeed(PlayerId playerId, bytes32 commitString)
        external
        nonReentrant
        onlyPlayerOfIdx(playerId)
    {
        // Check that the battle hasn't started yet.
        require(
            battleState == BattleState.Preparing,
            "The battle has already started."
        );

        // Check that the player seed hasn't set yet.
        require(
            _getRandomSlotState(playerId) == RandomSlotState.NotSet,
            "The playerSeed has already set."
        );

        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;

        // Check that player seed commitment is in time.
        if (
            block.number >
            playerSeedCommitStartPoint + PLAYER_SEED_COMMIT_TIME_LIMIT
        ) {
            emit TimeOutAtPlayerSeedCommitDetected(playerId);

            // ban the lazy player.
            _banLazyPlayer(playerId);

            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // enemy player is a lazy player too. ban the enemy player.
                _banLazyPlayer(enemyId);
            }

            // Cancel this battle.
            battleState = BattleState.Settled;
            revert BattleCanceled(playerId);
        }

        // Save commitment on the storage. The playerSeed of the player is hidden in the commit phase.
        playerSeedCommitLog[playerId] = PlayerSeedCommitment(
            commitString,
            bytes32(0)
        );

        // Emit the event that tells frontend that the player designated by playerId has committed.
        emit PlayerSeedCommitted(playerId);

        // Update the state of the random slot to be commited.
        playerInfoTable[playerId].randomSlot.state = RandomSlotState.Committed;

        // Generate nonce after player committed the playerSeed.
        bytes32 nonce = PLMSeeder.generateRandomSlotNonce();

        // Emit the event that tells frontend that the randomSlotNonce is generated for the player designated
        // by playerId.
        emit RandomSlotNounceGenerated(playerId, nonce);

        playerInfoTable[playerId].randomSlot.nonce = nonce;
        playerInfoTable[playerId].randomSlot.nonceSet = true;

        // If both players have already committed their player seeds, start the battle.
        if (_getRandomSlotState(enemyId) == RandomSlotState.Committed) {
            battleState = BattleState.RoundStarted;
        }

        // Set the block number when the round starts.
        choiceCommitStartPoints[numRounds] = block.number;
    }

    /// @param playerId: the identifier of the player. Alice or Bob.
    /// @param playerSeed: the choice the player designated by playerId committed in this round.
    ///                    bytes32(0) is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    function revealPlayerSeed(
        PlayerId playerId,
        bytes32 playerSeed,
        bytes32 bindingFactor
    )
        external
        roundStarted
        onlyPlayerOfIdx(playerId)
        readyForPlayerSeedRevealment(playerId)
    {
        // playerSeed is not allowed to be bytes32(0).
        require(
            playerSeed != bytes32(0),
            "bytes32(0) is not allowed for playerSeed."
        );

        // The pointer to the commit log of the player designated by playerId.
        PlayerSeedCommitment storage playerSeedCommitment = playerSeedCommitLog[
            playerId
        ];

        // Check the commit has coincides with the one stored on chain.
        require(
            keccak256(
                abi.encodePacked(msg.sender, playerSeed, bindingFactor)
            ) == playerSeedCommitment.commitString,
            "Commit hash doesn't coincide."
        );

        // Execute revealment
        playerSeedCommitment.playerSeed = playerSeed;

        // Emit the event that tells frontend that the player designated by playerId has revealed.
        emit PlayerSeedRevealed(numRounds, playerId, playerSeed);

        // Update the state of the random slot to be revealed.
        playerInfoTable[playerId].randomSlot.state = RandomSlotState.Revealed;
    }

    /// @notice Commit the choice (the character the player choose to use in the current round).
    /// @param playerId: the identifier of the player. Alice or Bob.
    /// @param commitString: commitment string calculated by the player designated by playerId
    ///                      as keccak256(abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor)).
    function commitChoice(PlayerId playerId, bytes32 commitString)
        external
        nonReentrant
        roundStarted
        onlyPlayerOfIdx(playerId)
    {
        // Check that the player who want to commit haven't committed yet in this round.
        require(
            _getPlayerState(playerId) == PlayerState.Preparing,
            "This player is not in the state to commit in this round."
        );

        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;

        // Check that choice commitment is in time.
        if (
            block.number >
            choiceCommitStartPoints[numRounds] + CHOICE_COMMIT_TIME_LIMIT
        ) {
            emit TimeOutAtChoiceCommitDetected(numRounds, playerId);

            // ban the lazy player.
            _banLazyPlayer(playerId);

            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // enemy player is a lazy player too. ban the enemy player.
                _banLazyPlayer(enemyId);
            }

            // Cancel this battle.
            battleState = BattleState.Settled;
            revert BattleCanceled(playerId);
        }

        // Save commitment on the storage. The choice of the player is hidden in the commit phase.
        choiceCommitLog[numRounds][playerId] = ChoiceCommitment(
            commitString,
            0,
            Choice.Secret
        );

        // Emit the event that tells frontend that the player designated by playerId has committed.
        emit ChoiceCommitted(numRounds, playerId);

        // Update the state of the commit player to be committed.
        playerInfoTable[playerId].state = PlayerState.Committed;

        if (_getPlayerState(enemyId) == PlayerState.Committed) {
            // both players have already committed.
            choiceRevealStartPoints[numRounds] = block.number;
        }
    }

    /// @notice Reveal the committed choice by the player who committed it in this round.
    /// @param playerId: the identifier of the player. Alice or Bob.
    /// @param levelPoint: the levelPoint the player uses to the chosen character.
    /// @param choice: the choice the player designated by playerId committed in this round.
    ///                Choice.Secret is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    function revealChoice(
        PlayerId playerId,
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    )
        external
        roundStarted
        onlyPlayerOfIdx(playerId)
        readyForChoiceRevealment(playerId)
    {
        // Choice.Secret is not allowed for the choice passed to the reveal function.
        require(
            choice != Choice.Secret,
            "Choice.Secret is not allowed when revealing."
        );

        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;

        // Check that choice revealment is in time.
        if (
            block.number >
            choiceRevealStartPoints[numRounds] + CHOICE_REVEAL_TIME_LIMIT
        ) {
            emit TimeOutAtChoiceRevealDetected(numRounds, playerId);

            // ban the lazy player.
            _banLazyPlayer(playerId);

            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // enemy player is a lazy player too. ban the enemy player.
                _banLazyPlayer(enemyId);
            }

            // Cancel this battle.
            battleState = BattleState.Settled;
            revert BattleCanceled(playerId);
        }

        // If the choice is the random slot, then random slot must have already been revealed.
        if (choice == Choice.Random) {
            require(
                _getRandomSlotState(playerId) == RandomSlotState.Revealed,
                "Random slot cannot be used because player seed is not revealed yet."
            );
        }

        // The pointer to the commit log of the player designated by playerId.
        ChoiceCommitment storage choiceCommitment = choiceCommitLog[numRounds][
            playerId
        ];

        // Check the commit hash coincides with the one stored on chain.
        require(
            keccak256(
                abi.encodePacked(msg.sender, levelPoint, choice, bindingFactor)
            ) == choiceCommitment.commitString,
            "Commit hash doesn't coincide."
        );

        // Check that the levelPoint is less than or equal to the remainingLevelPoint.
        uint8 remainingLevelPoint = _getRemainingLevelPoint(playerId);
        if (levelPoint > remainingLevelPoint) {
            emit ExceedingLevelPointCheatDetected(
                playerId,
                remainingLevelPoint,
                levelPoint
            );

            // End this match and ban the player designated by playerId.
            _banCheater(playerId);

            // Cancel this battle.
            battleState = BattleState.Settled;
            revert BattleCanceled(playerId);
        }

        // Subtract revealed levelPoint from remainingLevelPoint
        playerInfoTable[playerId].remainingLevelPoint -= levelPoint;

        // Check that the chosen slot hasn't been used yet.
        // If the revealed slot has already used, then end this match and ban the player designated by playerId.
        if (
            (choice == Choice.Random && _getRandomSlotUsedFlag(playerId)) ||
            (choice != Choice.Random &&
                _getFixedSlotUsedFlag(playerId, uint8(choice)))
        ) {
            emit ReusingUsedSlotCheatDetected(playerId, choice);

            // End this match and ban the player designated by playerId.
            _banCheater(playerId);

            // Cancel this battle.
            battleState = BattleState.Settled;
            revert BattleCanceled(playerId);
        }

        // Execute revealment
        choiceCommitment.levelPoint = levelPoint;
        choiceCommitment.choice = choice;

        // Emit the event that tells frontend that the player designated by playerId has revealed.
        emit ChoiceRevealed(numRounds, playerId, levelPoint, choice);

        // Update the state of the reveal player to be Revealed.
        playerInfoTable[playerId].state = PlayerState.Revealed;

        if (_getPlayerState(enemyId) == PlayerState.Revealed) {
            _stepRound();
        }
    }

    function getBattleState() external view returns (BattleState) {
        return battleState;
    }

    function getRemainingLevel(PlayerId playerId)
        external
        view
        returns (uint256)
    {
        return playerInfoTable[playerId].remainingLevelPoint;
    }

    /// @notice Function to execute the current round.
    function _stepRound()
        internal
        nonReentrant
        roundStarted
        readyForRoundSettlement
    {
        // Mark the slot as used.
        _markSlot(PlayerId.Alice);
        _markSlot(PlayerId.Bob);

        // Calculate the damage of both players.
        IPLMToken.CharacterInfo memory aliceChar = _getChosenCharacterInfo(
            PlayerId.Alice
        );
        IPLMToken.CharacterInfo memory bobChar = _getChosenCharacterInfo(
            PlayerId.Bob
        );
        uint8 aliceDamage;
        uint8 bobDamage;
        (aliceDamage, bobDamage) = token.calcBattleResult(aliceChar, bobChar);

        if (aliceDamage > bobDamage) {
            // Alice wins !!
            playerInfoTable[PlayerId.Alice].winCount++;

            emit RoundResult(
                numRounds,
                false,
                PlayerId.Alice,
                PlayerId.Bob,
                aliceDamage,
                bobDamage
            );
        } else if (aliceDamage < bobDamage) {
            // Bob wins !!
            playerInfoTable[PlayerId.Bob].winCount++;

            emit RoundResult(
                numRounds,
                false,
                PlayerId.Bob,
                PlayerId.Alice,
                bobDamage,
                aliceDamage
            );
        } else {
            // Draw !!
            emit RoundResult(
                numRounds,
                true,
                PlayerId.Alice,
                PlayerId.Bob,
                aliceDamage,
                bobDamage
            );
        }

        // Increment the round number.
        numRounds++;
        if (
            _getWinCount(PlayerId.Alice) == WIN_COUNT ||
            _getWinCount(PlayerId.Bob) == WIN_COUNT ||
            numRounds == MAX_ROUNDS
        ) {
            // This battle ends.
            battleState = BattleState.RoundSettled;
            _settleBattle();
            return;
        }

        // Reset the player states.
        playerInfoTable[PlayerId.Alice].state = PlayerState.Preparing;
        playerInfoTable[PlayerId.Bob].state = PlayerState.Preparing;

        // Set the block number when the next round starts.
        choiceCommitStartPoints[numRounds] = block.number;
    }

    /// @notice Function to ban the cheater
    /// @dev Ban the account (subtract constant block number from the subscribing period limit.)
    function _banCheater(PlayerId playerId) internal {
        // Reduce the subscribing period to ban the cheater account.
        dealer.banAccount(
            _getPlayerAddress(playerId),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_CHEATER
        );

        // Cancel this battle.
        battleState = BattleState.Settled;
    }

    /// @notice Function to ban the lazy player
    /// @dev Ban the account (subtract constant block number from the subscribing period limit.)
    function _banLazyPlayer(PlayerId playerId) internal {
        // Reduce the subscribing period to ban the cheater account.
        dealer.banAccount(
            _getPlayerAddress(playerId),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_LAZY_ACCOUNT
        );
    }

    /// @notice Core logic to finalization of the battle.
    function _settleBattle() internal virtual readyForBattleSettlement {
        uint8 aliceWinCount = _getWinCount(PlayerId.Alice);
        uint8 bobWinCount = _getWinCount(PlayerId.Bob);

        // Pay rewards (PLMCoin) to the winner from dealer.
        if (aliceWinCount > bobWinCount) {
            // Alice Wins !!
            _payRewards(PlayerId.Alice, PlayerId.Bob);
        } else if (aliceWinCount < bobWinCount) {
            // BoB Wins !!
            _payRewards(PlayerId.Bob, PlayerId.Alice);
        } else {
            _payRewardsDraw();
        }

        battleState = BattleState.Settled;
    }

    /// @notice Function to pay reward to the winner.
    /// @dev This logic is derived from Pokemon.
    function _payRewards(PlayerId winner, PlayerId loser) internal {
        // Calculate the reward balance of the winner.
        uint16 winnerTotalLevel = _getTotalLevel(winner);
        uint16 loserTotalLevel = _getTotalLevel(loser);
        uint48 top = uint48(loserTotalLevel) *
            (uint48(loserTotalLevel) * 2 + 102)**3;
        uint48 bottom = 51 *
            (uint48(winnerTotalLevel) + uint48(loserTotalLevel) + 102)**3;
        uint256 amount = top / bottom;

        // Dealer pay rewards to the winner.
        dealer.payReward(_getPlayerAddress(winner), uint256(amount));
    }

    /// @notice Function to pay reward to both players when draws.
    /// @dev This logic is derived from Pokemon.
    function _payRewardsDraw() internal {
        // Calculate the reward balance of both players.
        uint16 aliceTotalLevel = _getTotalLevel(PlayerId.Alice);
        uint16 bobTotalLevel = _getTotalLevel(PlayerId.Bob);
        uint48 aliceTop = uint48(aliceTotalLevel) *
            (uint48(aliceTotalLevel) * 2 + 102)**3;
        uint48 bobTop = uint48(bobTotalLevel) *
            (uint48(bobTotalLevel) * 2 + 102)**3;
        uint48 bottom = 51 *
            (uint48(aliceTotalLevel) + uint48(bobTotalLevel) + 102)**3;
        uint256 aliceAmount = aliceTop / bottom / 2;
        uint256 bobAmount = bobTop / bottom / 2;

        // Dealer pay rewards to both players.
        dealer.payReward(_getPlayerAddress(PlayerId.Alice), aliceAmount);
        dealer.payReward(_getPlayerAddress(PlayerId.Bob), bobAmount);
    }

    /// @notice Function to start the battle.
    function startBattle(
        address aliceAddr,
        address bobAddr,
        uint256 aliceBlockNum,
        uint256 bobBlockNum,
        uint256[FIXEDSLOT_NUM] memory aliceFixedSlots,
        uint256[FIXEDSLOT_NUM] memory bobFixedSlots
    ) public readyForBattleStart {
        IPLMToken.CharacterInfo[FIXEDSLOT_NUM] memory aliceCharInfos;
        IPLMToken.CharacterInfo[FIXEDSLOT_NUM] memory bobCharInfos;

        // Retrieve character infomation by tokenId in the fixed slots.
        for (uint8 i = 0; i < FIXEDSLOT_NUM; i++) {
            aliceCharInfos[i] = token.getPriorCharacterInfo(
                aliceFixedSlots[i],
                aliceBlockNum
            );
            bobCharInfos[i] = token.getPriorCharacterInfo(
                bobFixedSlots[i],
                bobBlockNum
            );
        }

        // Get level point for both players.
        uint8 aliceLevelPoint = token.calcLevelPoint(aliceCharInfos);
        uint8 bobLevelPoint = token.calcLevelPoint(bobCharInfos);

        // Initial state of random slot.
        RandomSlot memory initRandomSlot = RandomSlot(
            0,
            bytes32(0),
            false,
            false,
            RandomSlotState.NotSet
        );

        PlayerInfo memory aliceInfo = PlayerInfo(
            aliceAddr,
            aliceBlockNum,
            aliceFixedSlots,
            [false, false, false, false],
            initRandomSlot,
            PlayerState.Preparing,
            0,
            aliceLevelPoint
        );
        PlayerInfo memory bobInfo = PlayerInfo(
            bobAddr,
            bobBlockNum,
            bobFixedSlots,
            [false, false, false, false],
            initRandomSlot,
            PlayerState.Preparing,
            0,
            bobLevelPoint
        );

        // Set the initial character information.
        playerInfoTable[PlayerId.Alice] = aliceInfo;
        playerInfoTable[PlayerId.Bob] = bobInfo;

        // Change battle state to wait for the playerSeed commitment.
        battleState = BattleState.Preparing;

        // Set the block number when the battle has started.
        playerSeedCommitStartPoint = block.number;
    }

    /// @notice Function to mark the slot used in the current round as used.
    function _markSlot(PlayerId playerId) internal {
        Choice choice = choiceCommitLog[numRounds][playerId].choice;
        if (choice == Choice.Random) {
            playerInfoTable[playerId].randomSlot.used = true;
        } else if (choice == Choice.Secret) {
            revert("Unreachable!");
        } else {
            playerInfoTable[playerId].slotsUsed[uint8(choice)] = true;
        }
    }

    /// @notice Function to calculate the total level of the fixed slots.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function _getTotalLevel(PlayerId playerId) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 i = 0; i < FIXEDSLOT_NUM; i++) {
            totalLevel += token
                .getPriorCharacterInfo(
                    _getFixedSlotTokenId(playerId, i),
                    playerInfoTable[playerId].startBlockNum
                )
                .level;
        }
        return totalLevel;
    }

    /// @notice Function to return the player's remainingLevelPoint.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function _getRemainingLevelPoint(PlayerId playerId)
        internal
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].remainingLevelPoint;
    }

    /// @notice Function to return the character information used in this round.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function _getChosenCharacterInfo(PlayerId playerId)
        internal
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        require(
            playerId == PlayerId.Alice || playerId == PlayerId.Bob,
            "Invalid playerId."
        );

        Choice choice = choiceCommitLog[numRounds][playerId].choice;

        uint256 tokenId;
        if (choice == Choice.Random) {
            // Player's choice is random slot.
            tokenId = PLMSeeder.getRandomSlotTokenId(
                _getNonce(playerId),
                _getPlayerSeed(playerId),
                token
            );
        } else if (choice == Choice.Secret) {
            revert("Unreachable !");
        } else {
            // Player's choice is in fixed slots.
            tokenId = _getFixedSlotTokenId(playerId, uint8(choice));
        }

        // Retrieve the character information.
        IPLMToken.CharacterInfo memory charInfo = token.getPriorCharacterInfo(
            tokenId,
            playerInfoTable[playerId].startBlockNum
        );

        if (choice == Choice.Random) {
            charInfo.level = _getRandomSlotLevel(playerId);
        }

        return charInfo;
    }

    function _getRandomSlotState(PlayerId playerId)
        internal
        view
        returns (RandomSlotState)
    {
        return playerInfoTable[playerId].randomSlot.state;
    }

    function _getRandomSlotLevel(PlayerId playerId)
        internal
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].randomSlot.level;
    }

    function _getRandomSlotUsedFlag(PlayerId playerId)
        internal
        view
        returns (bool)
    {
        return playerInfoTable[playerId].randomSlot.used;
    }

    function _getNonce(PlayerId playerId) internal view returns (bytes32) {
        require(
            playerInfoTable[playerId].randomSlot.nonceSet,
            "Nonce hasn't been set."
        );
        return playerInfoTable[playerId].randomSlot.nonce;
    }

    function _getWinCount(PlayerId playerId) internal view returns (uint8) {
        return playerInfoTable[playerId].winCount;
    }

    function _getPlayerSeed(PlayerId playerId) internal view returns (bytes32) {
        require(
            _getRandomSlotState(playerId) == RandomSlotState.Revealed,
            "random slot hasn't been revealed yet."
        );
        return playerSeedCommitLog[playerId].playerSeed;
    }

    function _getPlayerState(PlayerId playerId)
        internal
        view
        returns (PlayerState)
    {
        return playerInfoTable[playerId].state;
    }

    function _getPlayerAddress(PlayerId playerId)
        internal
        view
        returns (address)
    {
        return playerInfoTable[playerId].addr;
    }

    function _getFixedSlotTokenId(PlayerId playerId, uint8 fixedSlotIdx)
        internal
        view
        returns (uint256)
    {
        require(fixedSlotIdx < FIXEDSLOT_NUM, "Invalid fixed slot index.");
        return playerInfoTable[playerId].fixedSlots[fixedSlotIdx];
    }

    function _getFixedSlotUsedFlag(PlayerId playerId, uint8 fixedSlotIdx)
        internal
        view
        returns (bool)
    {
        require(fixedSlotIdx < FIXEDSLOT_NUM, "Invalid fixed slot index.");
        return playerInfoTable[playerId].slotsUsed[fixedSlotIdx];
    }
}
