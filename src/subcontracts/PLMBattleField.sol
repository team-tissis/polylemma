// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "../lib/PLMSeeder.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "../interfaces/IPLMToken.sol";
import {IPLMDealer} from "../interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "../interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "../interfaces/IPLMMatchOrganizer.sol";

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

    /// @notice The limit of commitment for each player. About 60 seconds.
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 30;

    /// @notice The limit of revealment for each player. About 30 seconds.
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 15;

    /// @notice interface to the dealer of polylemma.
    IPLMDealer dealer;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice interface to the MatchOrganizer.
    IPLMMatchOrganizer mo;

    address polylemmer;
    address matchOrganizer;

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

    constructor(IPLMDealer _dealer, IPLMToken _token) {
        dealer = _dealer;
        token = _token;
        polylemmer = msg.sender;
    }

    /// @notice Check whether the caller of the function is the valid account.
    /// @param playerId: The player's identifier.
    modifier onlyPlayerOfIdx(PlayerId playerId) {
        require(
            playerId == PlayerId.Alice || playerId == PlayerId.Bob,
            "Invalid plyrId."
        );
        require(
            msg.sender == playerInfoTable[playerId].addr,
            "The caller plyr is not the valid account."
        );
        _;
    }

    /// @notice Check that the battle round has already started.
    modifier roundStarted() {
        require(
            _getRandomSlotState(PlayerId.Alice) != RandomSlotState.NotSet &&
                _getRandomSlotState(PlayerId.Bob) != RandomSlotState.NotSet,
            "rand sl. haven't set yet."
        );
        require(
            battleState == BattleState.RoundStarted,
            "battle round hasn't started yet."
        );
        _;
    }

    modifier onlyPolylemmer() {
        require(msg.sender == polylemmer, "sender is not polylemmer");
        _;
    }
    modifier onlyMatchOrganizer() {
        require(msg.sender == matchOrganizer, "sender is not matchOrganizer");
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

        PlayerId enemyId = _enemyId(playerId);

        require(
            _getPlayerState(playerId) == PlayerState.Committed &&
                (_getPlayerState(enemyId) == PlayerState.Committed ||
                    _getPlayerState(enemyId) == PlayerState.Revealed),
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

        PlayerId enemyId = _enemyId(playerId);
        PlayerState enemyState = _getPlayerState(enemyId);

        // If the enemy player has not committed yet and it's over commit time limit,
        // ban the enemy player as lazy player.
        if (
            enemyState == PlayerState.Preparing &&
            block.number >
            choiceCommitStartPoints[numRounds] + CHOICE_COMMIT_TIME_LIMIT
        ) {
            emit TimeOutAtChoiceCommitDetected(numRounds, enemyId);

            // ban the enemy player.
            _banLazyPlayer(enemyId);

            emit BattleCanceled(enemyId);
            return;
        }

        // If the enemy player has not committed yet and it's not over commit time limit,
        // player has to wait until commit time limit. So, in this case, we revert the
        // revealChoice function using require statement below.
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
    ///                      as keccak256(abi.encodePacked(msg.sender, playerSeed)).
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

        PlayerId enemyId = _enemyId(playerId);

        // Check that player seed commitment is in time.
        if (
            block.number >
            playerSeedCommitStartPoint + PLAYER_SEED_COMMIT_TIME_LIMIT
        ) {
            emit TimeOutAtPlayerSeedCommitDetected(playerId);

            // ban the lazy player.
            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // both players are lazy players.
                _banLazyPlayers();
            } else {
                // only the player designated by playerId is a lazy player.
                _banLazyPlayer(playerId);
            }

            emit BattleCanceled(playerId);
            return;
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
    function revealPlayerSeed(PlayerId playerId, bytes32 playerSeed)
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
            keccak256(abi.encodePacked(msg.sender, playerSeed)) ==
                playerSeedCommitment.commitString,
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
            "not in the state to commit in this round."
        );

        PlayerId enemyId = _enemyId(playerId);

        // Check that choice commitment is in time.
        if (
            block.number >
            choiceCommitStartPoints[numRounds] + CHOICE_COMMIT_TIME_LIMIT
        ) {
            emit TimeOutAtChoiceCommitDetected(numRounds, playerId);

            // ban the lazy player.
            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // both players are lazy players.
                _banLazyPlayers();
            } else {
                // only the player designated by playerId is a lazy player.
                _banLazyPlayer(playerId);
            }

            emit BattleCanceled(playerId);
            return;
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
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    /// @param playerId: the identifier of the player. Alice or Bob.
    /// @param levelPoint: the levelPoint the player uses to the chosen character.
    /// @param choice: the choice the player designated by playerId committed in this round.
    ///                Choice.Secret is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
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
            "Choice.Scrt is not allowed when revealn."
        );

        PlayerId enemyId = _enemyId(playerId);

        // Check that choice revealment is in time.
        if (
            block.number >
            choiceRevealStartPoints[numRounds] + CHOICE_REVEAL_TIME_LIMIT
        ) {
            emit TimeOutAtChoiceRevealDetected(numRounds, playerId);

            // ban the lazy player.
            if (_getPlayerState(enemyId) == PlayerState.Preparing) {
                // both players are lazy players.
                _banLazyPlayers();
            } else {
                // only the player designated by playerId is a lazy player.
                _banLazyPlayer(playerId);
            }

            emit BattleCanceled(playerId);
            return;
        }

        // If the choice is the random slot, then random slot must have already been revealed.
        if (choice == Choice.Random) {
            require(
                _getRandomSlotState(playerId) == RandomSlotState.Revealed,
                "Ran. sl. cannot be used because plr sd not revealed yet."
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

            emit BattleCanceled(playerId);
            return;
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

            emit BattleCanceled(playerId);
            return;
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

    /// @notice Function to report enemy player for lazy revealment.
    /// @dev This function is prepared to deal with the case that one of the player
    ///      don't reveal his/her choice and it locked the battle forever.
    ///      In this case, if the enemy (honest) player report him/her after the
    ///      choice revealmenet timelimit, then the lazy player will be banned,
    ///      the battle will be canceled, and the stamina of the honest player will
    ///      be refunded.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function reportLazyRevealment(PlayerId playerId)
        external
        roundStarted
        onlyPlayerOfIdx(playerId)
    {
        PlayerId enemyId = _enemyId(playerId);

        // Detect enemy player's lazy revealment.
        require(
            _getPlayerState(_enemyId(playerId)) == PlayerState.Committed &&
                block.number >
                choiceRevealStartPoints[numRounds] + CHOICE_REVEAL_TIME_LIMIT,
            "Check this rep. is valid."
        );

        emit TimeOutAtChoiceRevealDetected(numRounds, enemyId);

        // ban the lazy player.
        _banLazyPlayer(enemyId);

        emit BattleCanceled(playerId);
    }

    /// @notice Function to start the battle.
    /// @dev This function is called from match organizer.
    /// @param aliceAddr: the address of the player assigned to Alice.
    /// @param bobAddr: the address of the player assigned to Bob.
    /// @param aliceBlockNum: the block number used to view Alice's characters' info.
    /// @param bobBlockNum: the block number used to view Bob's characters' info.
    /// @param aliceFixedSlots: tokenIds of Alice's fixed slots.
    /// @param bobFixedSlots: tokenIds of Bob's fixed slots.
    function startBattle(
        address aliceAddr,
        address bobAddr,
        uint256 aliceBlockNum,
        uint256 bobBlockNum,
        uint256[FIXEDSLOT_NUM] memory aliceFixedSlots,
        uint256[FIXEDSLOT_NUM] memory bobFixedSlots
    ) public readyForBattleStart onlyMatchOrganizer {
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

        // Initialize random slots.
        RandomSlot memory aliceRandomSlot = RandomSlot(
            token.calcRandomSlotLevel(aliceCharInfos),
            bytes32(0),
            false,
            false,
            RandomSlotState.NotSet
        );
        RandomSlot memory bobRandomSlot = RandomSlot(
            token.calcRandomSlotLevel(bobCharInfos),
            bytes32(0),
            false,
            false,
            RandomSlotState.NotSet
        );

        // Initialize both players' information.
        PlayerInfo memory aliceInfo = PlayerInfo(
            aliceAddr,
            aliceBlockNum,
            aliceFixedSlots,
            [false, false, false, false],
            aliceRandomSlot,
            PlayerState.Preparing,
            0,
            aliceLevelPoint
        );
        PlayerInfo memory bobInfo = PlayerInfo(
            bobAddr,
            bobBlockNum,
            bobFixedSlots,
            [false, false, false, false],
            bobRandomSlot,
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

        // Reset round number.
        numRounds = 0;

        emit BattleStarted(aliceAddr, bobAddr);
    }

    /// @notice Function to execute the current round.
    /// @dev This function is automatically called after both players' choice revealment
    ///      of this round.
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

        uint32 aliceBondLevel = token.calcPriorBondLevel(
            aliceChar.level,
            aliceChar.fromBlock,
            _getStartBlockNum(PlayerId.Bob)
        );
        uint32 alicePower = token.calcPower(
            numRounds,
            aliceChar,
            choiceCommitLog[numRounds][PlayerId.Alice].levelPoint,
            aliceBondLevel,
            bobChar
        );

        uint32 bobBondLevel = token.calcPriorBondLevel(
            bobChar.level,
            bobChar.fromBlock,
            _getStartBlockNum(PlayerId.Bob)
        );
        uint32 bobPower = token.calcPower(
            numRounds,
            bobChar,
            choiceCommitLog[numRounds][PlayerId.Bob].levelPoint,
            bobBondLevel,
            aliceChar
        );

        // Judge the battle result of this round.
        if (alicePower > bobPower) {
            // Alice wins !!
            playerInfoTable[PlayerId.Alice].winCount++;

            emit RoundResult(
                numRounds,
                false,
                PlayerId.Alice,
                PlayerId.Bob,
                alicePower,
                bobPower
            );
        } else if (alicePower < bobPower) {
            // Bob wins !!
            playerInfoTable[PlayerId.Bob].winCount++;

            emit RoundResult(
                numRounds,
                false,
                PlayerId.Bob,
                PlayerId.Alice,
                bobPower,
                alicePower
            );
        } else {
            // Draw !!
            emit RoundResult(
                numRounds,
                true,
                PlayerId.Alice,
                PlayerId.Bob,
                alicePower,
                bobPower
            );
        }

        // Increment the round number.
        numRounds++;
        uint8 aliceWinCount = _getWinCount(PlayerId.Alice);
        uint8 bobWinCount = _getWinCount(PlayerId.Bob);

        uint8 diffWinCount = aliceWinCount > bobWinCount
            ? aliceWinCount - bobWinCount
            : bobWinCount - aliceWinCount;

        // Check whether the battle round continues or not.
        if (
            aliceWinCount == WIN_COUNT ||
            bobWinCount == WIN_COUNT ||
            numRounds == MAX_ROUNDS ||
            diffWinCount > (MAX_ROUNDS - numRounds)
        ) {
            // This battle ends.
            battleState = BattleState.RoundSettled;
            _settleBattle();

            // Check draw condition.
            bool isDraw = aliceWinCount == bobWinCount;

            PlayerId winner = aliceWinCount >= bobWinCount
                ? PlayerId.Alice
                : PlayerId.Bob;
            PlayerId loser = _enemyId(winner);
            uint8 winCount = _getWinCount(winner);
            uint8 loseCount = _getWinCount(loser);

            emit BattleResult(
                numRounds - 1,
                isDraw,
                winner,
                loser,
                winCount,
                loseCount
            );
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

        // Refund stamina to the enemy player.
        dealer.refundStaminaForBattle(_getPlayerAddress(_enemyId(playerId)));

        // Cancel this battle.
        _cancelBattle();
    }

    /// @notice Function to ban the lazy player
    /// @dev Ban the account (subtract constant block number from the subscribing period limit.)
    function _banLazyPlayer(PlayerId playerId) internal {
        // Reduce the subscribing period to ban the lazy palyer's account.
        dealer.banAccount(
            _getPlayerAddress(playerId),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_LAZY_ACCOUNT
        );

        // Refund stamina to the enemy player.
        dealer.refundStaminaForBattle(_getPlayerAddress(_enemyId(playerId)));

        // Cancel this battle.
        _cancelBattle();
    }

    /// @notice Function to ban both players because of lazyness.
    /// @dev Ban the account (subtract constant block number from the subscribing period limit.)
    function _banLazyPlayers() internal {
        // Reduce the subscribing period to ban the lazy players' accounts.
        dealer.banAccount(
            _getPlayerAddress(PlayerId.Alice),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_LAZY_ACCOUNT
        );
        dealer.banAccount(
            _getPlayerAddress(PlayerId.Bob),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_LAZY_ACCOUNT
        );

        // No stamina refund called here because both players are lazy players.
        // Cancel this battle.
        _cancelBattle();
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

        // Update the proposal state.
        mo.updateProposalState2NonProposal(
            playerInfoTable[PlayerId.Alice].addr,
            playerInfoTable[PlayerId.Bob].addr
        );

        // settle this battle.
        battleState = BattleState.Settled;
    }

    /// @notice called in _banCheater function.
    function _cancelBattle() internal virtual {
        // TODO: modify here when we implement multislot battle.
        mo.updateProposalState2NonProposal(
            playerInfoTable[PlayerId.Alice].addr,
            playerInfoTable[PlayerId.Bob].addr
        );
        battleState = BattleState.Settled;
    }

    /// @notice Function to pay reward to the winner.
    /// @dev This logic is derived from Pokemon.
    function _payRewards(PlayerId winner, PlayerId loser) internal {
        // Calculate the reward balance of the winner.
        uint16 winnerTotalLevel = _getTotalLevel(winner);
        uint16 loserTotalLevel = _getTotalLevel(loser);

        // Pokemon inspired reward calculation.
        uint48 top = 51 *
            uint48(loserTotalLevel) *
            (uint48(loserTotalLevel) * 2 + 102)**3;
        uint48 bottom = (uint48(winnerTotalLevel) +
            uint48(loserTotalLevel) +
            102)**3;
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

        // Pokemon inspired reward calculation.
        uint48 aliceTop = 51 *
            uint48(aliceTotalLevel) *
            (uint48(aliceTotalLevel) * 2 + 102)**3;
        uint48 bobTop = 51 *
            uint48(bobTotalLevel) *
            (uint48(bobTotalLevel) * 2 + 102)**3;
        uint48 bottom = (uint48(aliceTotalLevel) +
            uint48(bobTotalLevel) +
            102)**3;

        // The total amount of rewards are smaller then non-draw case.
        uint256 aliceAmount = aliceTop / bottom / 3;
        uint256 bobAmount = bobTop / bottom / 3;

        // Dealer pay rewards to both players.
        dealer.payReward(_getPlayerAddress(PlayerId.Alice), aliceAmount);
        dealer.payReward(_getPlayerAddress(PlayerId.Bob), bobAmount);
    }

    /// @notice Function to mark the slot used in the current round as used.
    /// @dev This function is called before step round.
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

    ////////////////////////
    ///      UTILS       ///
    ////////////////////////

    /// @notice function to get enemy's playerId.
    function _enemyId(PlayerId playerId) internal pure returns (PlayerId) {
        return playerId == PlayerId.Alice ? PlayerId.Bob : PlayerId.Alice;
    }

    ////////////////////////
    ///      GETTER      ///
    ////////////////////////

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

    function getNonce(PlayerId playerId) public view returns (bytes32) {
        require(playerInfoTable[playerId].randomSlot.nonceSet, "no nonce set.");
        return playerInfoTable[playerId].randomSlot.nonce;
    }

    function getFixedSlotCharInfo(PlayerId playerId)
        public
        view
        returns (IPLMToken.CharacterInfo[FIXEDSLOT_NUM] memory)
    {
        IPLMToken.CharacterInfo[FIXEDSLOT_NUM] memory playerCharInfos;
        for (uint8 i = 0; i < FIXEDSLOT_NUM; i++) {
            playerCharInfos[i] = _getFixedSlotCharInfoOfIdx(playerId, i);
        }

        return playerCharInfos;
    }

    function getVirtualRandomSlotCharInfo(PlayerId playerId, uint256 tokenId)
        external
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        IPLMToken.CharacterInfo memory virtualPlayerCharInfo = token
            .getPriorCharacterInfo(tokenId, _getStartBlockNum(playerId));
        virtualPlayerCharInfo.level = _getRandomSlotLevel(playerId);

        return virtualPlayerCharInfo;
    }

    function getRandomSlotCharInfo(PlayerId playerId)
        public
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        require(
            _getRandomSlotState(playerId) == RandomSlotState.Revealed,
            "Random slot character info has not determined yet."
        );
        // Calculate the tokenId of random slot for player designated by PlayerId.
        uint256 tokenId = PLMSeeder.getRandomSlotTokenId(
            getNonce(playerId),
            _getPlayerSeed(playerId),
            getTotalSupplyAtBattleStart(playerId)
        );

        IPLMToken.CharacterInfo memory playerCharInfo = token
            .getPriorCharacterInfo(tokenId, _getStartBlockNum(playerId));
        playerCharInfo.level = _getRandomSlotLevel(playerId);

        return playerCharInfo;
    }

    function getPlayerIdFromAddress(address playerAddr)
        public
        view
        returns (PlayerId)
    {
        bytes32 playerAddrBytes = keccak256(abi.encodePacked(playerAddr));
        bytes32 aliceAddrBytes = keccak256(
            abi.encodePacked(playerInfoTable[PlayerId.Alice].addr)
        );
        bytes32 bobAddrBytes = keccak256(
            abi.encodePacked(playerInfoTable[PlayerId.Bob].addr)
        );
        require(
            playerAddrBytes == aliceAddrBytes ||
                playerAddrBytes == bobAddrBytes,
            "The player designated by playerAddress is not in the battle."
        );
        return
            playerAddrBytes == aliceAddrBytes ? PlayerId.Alice : PlayerId.Bob;
    }

    function getBondLevelAtBattleStart(uint8 level, uint256 startBlock)
        public
        view
        returns (uint32)
    {
        return
            token.calcPriorBondLevel(
                level,
                startBlock,
                _getStartBlockNum(PlayerId.Bob)
            );
    }

    function getTotalSupplyAtBattleStart(PlayerId playerId)
        public
        view
        returns (uint256)
    {
        // Here we assume that Bob is always a requester.
        return token.getPriorTotalSupply(_getStartBlockNum(playerId));
    }

    function getRemainingLevelPoint(PlayerId playerId)
        external
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].remainingLevelPoint;
    }

    /// @notice Function to calculate the total level of the fixed slots.
    /// @param playerId: the identifier of the player. Alice or Bob.
    function _getTotalLevel(PlayerId playerId) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 i = 0; i < FIXEDSLOT_NUM; i++) {
            totalLevel += token
                .getPriorCharacterInfo(
                    _getFixedSlotTokenId(playerId, i),
                    _getStartBlockNum(playerId)
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

        if (choice == Choice.Random) {
            // Player's choice is in a random slot.
            return getRandomSlotCharInfo(playerId);
        } else if (choice == Choice.Secret) {
            revert("Unreachable !");
        } else {
            // Player's choice is in fixed slots.
            return _getFixedSlotCharInfoOfIdx(playerId, uint8(choice));
        }
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

    function _getWinCount(PlayerId playerId) internal view returns (uint8) {
        return playerInfoTable[playerId].winCount;
    }

    function _getPlayerSeed(PlayerId playerId) internal view returns (bytes32) {
        require(
            _getRandomSlotState(playerId) == RandomSlotState.Revealed,
            "rand. sl. hasn't been revealed yet."
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

    function _getStartBlockNum(PlayerId playerId)
        internal
        view
        returns (uint256)
    {
        return playerInfoTable[playerId].startBlockNum;
    }

    function _getFixedSlotCharInfoOfIdx(PlayerId playerId, uint8 fixedSlotIdx)
        internal
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        return
            token.getPriorCharacterInfo(
                _getFixedSlotTokenId(playerId, fixedSlotIdx),
                _getStartBlockNum(playerId)
            );
    }

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    /// @dev This contract and MatchOrganizer contract is referenced each other.
    ///      This is the reason why we have to prepare this function.
    function setIPLMMatchOrganizer(
        IPLMMatchOrganizer _mo,
        address _matchOrganizer
    ) external onlyPolylemmer {
        mo = _mo;
        matchOrganizer = _matchOrganizer;
    }

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////
    // FIXME: remove this function after demo.
    function forceInitBattle() public {
        battleState = BattleState.Settled;
        mo.setNonProposal(_getPlayerAddress(PlayerId.Alice));
        mo.setNonProposal(_getPlayerAddress(PlayerId.Bob));
    }
}
