// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMSeeder} from "./interfaces/IPLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PLMBattleField is IPLMBattleField, ReentrancyGuard {
    /// @notice The number of winning needed to win the match.
    uint8 constant WIN_COUNT = 3;

    /// @notice The number of the maximum round.
    uint8 constant MAX_ROUNDS = 5;

    /// @notice interface to the dealer of polylemma.
    IPLMDealer dealer;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice interface to the seeder.
    IPLMSeeder seeder;

    /// @notice interface to the character data.
    IPLMData data;

    /// @notice interface to the coin.
    IPLMCoin coin;

    /// @notice state of the battle.
    BattleState battleState;

    /// @notice number of rounds. (< MAX_ROUNDS)
    uint8 numRounds;

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
        require(
            _getPlayerState(playerId) == PlayerState.Revealed &&
                choiceCommitLog[numRounds][playerId].choice == Choice.Random,
            "The choice of the player has not been revealed or it is not randomSlot."
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

    constructor(
        IPLMDealer _dealer,
        IPLMToken _PLMToken,
        IPLMSeeder _PLMSeeder,
        IPLMData _PLMData,
        IPLMCoin _PLMCoin
    ) {
        dealer = _dealer;
        token = _PLMToken;
        seeder = _PLMSeeder;
        data = _PLMData;
        coin = _PLMCoin;
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
        bytes32 nonce = seeder.generateRandomSlotNonce();

        // Emit the event that tells frontend that the randomSlotNonce is generated for the player designated
        // by playerId.
        emit RandomSlotNounceGenerated(playerId, nonce);

        playerInfoTable[playerId].randomSlot.nonce = nonce;
        playerInfoTable[playerId].randomSlot.nonceSet = true;

        // If both players have already committed their player seeds, start the battle.
        PlayerId enemyId = playerId == PlayerId.Alice
            ? PlayerId.Bob
            : PlayerId.Alice;
        if (_getRandomSlotState(enemyId) == RandomSlotState.Committed) {
            battleState = BattleState.RoundStarted;
        }
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
        if (levelPoint > _getRamainingLevelPoint(playerId)) {
            // TODO: 配布されたレベルポイントを超えてしまったらもう戻せないので負け !!
        }

        // Subtract revealed levelPoint from remainingLevelPoint
        playerInfoTable[playerId].remainingLevelPoint -= levelPoint;

        // Check that the chosen slot hasn't been used yet.
        // TODO: 使用済みスロットを使っていたらもう戻せないので負け !!
        if (choice == Choice.Random) {
            require(
                !_getRandomSlotUsedFlag(playerId),
                "Random slot has already been used in the previous round."
            );
        } else {
            require(
                !_getFixedSlotUsedFlag(playerId, uint8(choice)),
                "Designated fixed slot has already been used in the previous round."
            );
        }

        // Execute revealment
        choiceCommitment.levelPoint = levelPoint;
        choiceCommitment.choice = choice;

        // Emit the event that tells frontend that the player designated by playerId has revealed.
        emit ChoiceRevealed(numRounds, playerId, levelPoint, choice);

        // Update the state of the reveal player to be Revealed.
        playerInfoTable[playerId].state = PlayerState.Revealed;
    }

    /// @notice Function to execute the current round.
    function stepRound()
        external
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
        (aliceDamage, bobDamage) = data.calcBattleResult(aliceChar, bobChar);

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
    }

    /// @notice Function to finalize the battle.
    /// @dev reward is paid from dealer to the winner of this battle.
    function _settleBattle() internal nonReentrant readyForBattleSettlement {
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
    function _startBattle(
        address aliceAddr,
        uint256[4] calldata aliceFixedSlots,
        address bobAddr,
        uint256[4] calldata bobFixedSlots
    ) internal readyForBattleStart {
        IPLMToken.CharacterInfo[4] memory aliceCharInfos;
        IPLMToken.CharacterInfo[4] memory bobCharInfos;

        // Retrieve character infomation by tokenId in the fixed slots.
        for (uint8 i = 0; i < 4; i++) {
            aliceCharInfos[i] = token.getCharacterInfo(aliceFixedSlots[i]);
            bobCharInfos[i] = token.getCharacterInfo(bobFixedSlots[i]);
        }

        // Get level point for both players.
        uint8 aliceLevelPoint = data.calcLevelPoint(aliceCharInfos);
        uint8 bobLevelPoint = data.calcLevelPoint(bobCharInfos);

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
            aliceFixedSlots,
            [false, false, false, false],
            initRandomSlot,
            PlayerState.Preparing,
            0,
            aliceLevelPoint
        );
        PlayerInfo memory bobInfo = PlayerInfo(
            bobAddr,
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
        for (uint8 i = 0; i < 4; i++) {
            totalLevel += token
                .getCharacterInfo(_getFixedSlotTokenId(playerId, i))
                .level;
        }
        return totalLevel;
    }

    /// @notice Function to return the player's remainingLevelPoint.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function _getRamainingLevelPoint(PlayerId playerId)
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
            tokenId = seeder.getRandomSlotTokenId(
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
        IPLMToken.CharacterInfo memory charInfo = token.getCharacterInfo(
            tokenId
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
        require(fixedSlotIdx < 4, "Invalid fixed slot index.");
        return playerInfoTable[playerId].fixedSlots[fixedSlotIdx];
    }

    function _getFixedSlotUsedFlag(PlayerId playerId, uint8 fixedSlotIdx)
        internal
        view
        returns (bool)
    {
        require(fixedSlotIdx < 4, "Invalid fixed slot index.");
        return playerInfoTable[playerId].slotsUsed[fixedSlotIdx];
    }
}
