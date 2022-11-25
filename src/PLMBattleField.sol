// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {PLMSeeder} from "./lib/PLMSeeder.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "./interfaces/IPLMMatchOrganizer.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

contract PLMBattleField is IPLMBattleField, ReentrancyGuard, IERC165 {
    /// @notice The number of the maximum round.
    uint8 constant MAX_ROUNDS = 5;

    /// @notice The number of the fixed slots that one player has.
    uint8 constant FIXED_SLOTS_NUM = 4;

    /// @notice The number of blocks generated per day.
    uint256 constant DAILY_BLOCK_NUM = 43200;

    /// @notice The length of the dates to ban cheater's account.
    uint256 constant BAN_DATE_LENGTH_FOR_CHEATER = 10;

    /// @notice The length of the dates to ban delayer's account.
    uint256 constant BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT = 2;

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
    IPLMMatchOrganizer matchOrganizer;

    /// @notice admin's address
    address polylemmers;

    /// @notice number of rounds. When on 1st round, numRounds==0 (< MAX_ROUNDS)
    uint8 numRounds;

    /// @notice state of the battle.
    BattleState battleState;

    // FIXME: It may be better to hold this information by mapping ... ??
    /// @notice array of the information on the winner and loser of each round
    RoundResult[MAX_ROUNDS] roundResults;

    /// @notice cache of the battle Result
    BattleResult battleResult;

    /// @notice block number when playerSeed commitment starts.
    uint256 playerSeedCommitFromBlock;

    // FIXME: It may be better to write uint256[MAX_ROUNDS] ... ??
    /// @notice block number log when choice committment starts for all rounds.
    mapping(uint8 => uint256) choiceCommitFromBlocks;

    // FIXME: It may be better to write uint256[MAX_ROUNDS] ... ??
    /// @notice block number log when choice revealment starts for all rounds.
    mapping(uint8 => uint256) choiceRevealFromBlocks;

    // FIXME: It may be better to write ChoiceCommit[2 * MAX_ROUNDS] ... ??
    /// @notice commitment log for all rounds.
    /// @dev The key is numRounds.
    mapping(uint8 => mapping(PlayerId => ChoiceCommit)) choiceCommitLog;

    // FIXME: PlayerSeedCommit[2] may be better ... ??
    /// @notice commitment log for player seed for random slot generation.
    mapping(PlayerId => PlayerSeedCommit) playerSeedCommitLog;

    /// @notice players' information
    mapping(PlayerId => PlayerInfo) playerInfoTable;

    constructor(IPLMDealer _dealer, IPLMToken _token) {
        dealer = _dealer;
        token = _token;
        polylemmers = msg.sender;
    }

    /// @notice Check whether the caller of the function is the valid account.
    /// @param playerId: The player's identifier.
    modifier onlyPlayerOf(PlayerId playerId) {
        require(
            msg.sender == _playerAddr(playerId),
            "caller != player of playerId"
        );
        _;
    }

    /// @notice Check that the battle round has already started.
    modifier inRound() {
        require(
            battleState == BattleState.InRound,
            "Battle round hasn't started yet"
        );
        _;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != polylemmers");
        _;
    }
    modifier onlyMatchOrganizer() {
        require(
            msg.sender == address(matchOrganizer),
            "sender != matchOrganizer"
        );
        _;
    }

    /// @notice Check that the random slot of the player designated by playerId
    ///         has already been committed, the choice of that player in this
    ///         round is randomSlot, and it has already been revealed.
    modifier readyForPlayerSeedReveal(PlayerId playerId) {
        // Prevent double revealing.
        require(
            _randomSlotState(playerId) == RandomSlotState.Committed,
            "playerSeed has already been revealed."
        );

        require(
            _playerState(playerId) == PlayerState.Committed &&
                (_playerState(_enemyId(playerId)) == PlayerState.Committed ||
                    _playerState(_enemyId(playerId)) == PlayerState.Revealed),
            "Home or Visitor hasn't committed one's choice yet"
        );
        _;
    }

    /// @notice Check that both players have already committed in this round.
    /// @param playerId: The player's identifier.
    modifier readyForChoiceReveal(PlayerId playerId) {
        require(
            _playerState(playerId) == PlayerState.Committed,
            "Player hasn't committed the choice yet"
        );

        PlayerState enemyState = _playerState(_enemyId(playerId));

        // If the enemy player has not committed yet and it's over commit time limit,
        // ban the enemy player as delayer.
        if (enemyState == PlayerState.Standby && _isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(numRounds, _enemyId(playerId));

            // Deal with the delayer (the player designated by playerId) and cancel
            // this battle.
            _dealWithDelayerAndCancelBattle(playerId);
            return;
        }

        // If the enemy player has not committed yet and it's not over commit time limit,
        // player has to wait until commit time limit. So, in this case, we revert the
        // revealChoice function using require statement below.
        require(
            enemyState == PlayerState.Committed ||
                enemyState == PlayerState.Revealed,
            "Enemy player hasn't committed the choice yet"
        );
        _;
    }

    /// @notice Check that this battle is ready for start.
    modifier readyForBattleStart() {
        // TODO: modify here when we extend battle field to multi slots.
        require(
            battleState == BattleState.NotStarted ||
                battleState == BattleState.Settled ||
                battleState == BattleState.Canceled,
            "Battle isn't ready for start."
        );
        _;
    }

    /// @notice Function to execute the current round.
    /// @dev This function is automatically called after both players' choice revealment
    ///      of this round.
    function _stepRound() internal {
        // Mark the slot as used.
        _markSlot(PlayerId.Home);
        _markSlot(PlayerId.Visitor);

        // Calculate the damage of both players.
        IPLMToken.CharacterInfo memory homeChar = _chosenCharacterInfo(
            PlayerId.Home
        );
        IPLMToken.CharacterInfo memory visitorChar = _chosenCharacterInfo(
            PlayerId.Visitor
        );

        uint32 homeDamage = token.getDamage(
            numRounds,
            homeChar,
            choiceCommitLog[numRounds][PlayerId.Home].levelPoint,
            token.getPriorBondLevel(
                homeChar.level,
                visitorChar.fromBlock,
                _fromBlock(PlayerId.Visitor)
            ),
            visitorChar
        );

        uint32 visitorDamage = token.getDamage(
            numRounds,
            visitorChar,
            choiceCommitLog[numRounds][PlayerId.Visitor].levelPoint,
            token.getPriorBondLevel(
                visitorChar.level,
                visitorChar.fromBlock,
                _fromBlock(PlayerId.Visitor)
            ),
            homeChar
        );

        // Judge the battle result of this round.
        if (homeDamage > visitorDamage) {
            // home wins !!
            playerInfoTable[PlayerId.Home].winCount++;

            roundResults[numRounds] = RoundResult(
                false,
                PlayerId.Home,
                PlayerId.Visitor,
                homeDamage,
                visitorDamage
            );
            emit RoundCompleted(
                numRounds,
                false,
                PlayerId.Home,
                PlayerId.Visitor,
                homeDamage,
                visitorDamage
            );
        } else if (homeDamage < visitorDamage) {
            // visitor wins !!
            playerInfoTable[PlayerId.Visitor].winCount++;
            roundResults[numRounds] = RoundResult(
                false,
                PlayerId.Visitor,
                PlayerId.Home,
                visitorDamage,
                homeDamage
            );
            emit RoundCompleted(
                numRounds,
                false,
                PlayerId.Visitor,
                PlayerId.Home,
                visitorDamage,
                homeDamage
            );
        } else {
            // Draw !!
            roundResults[numRounds] = RoundResult(
                true,
                PlayerId.Home,
                PlayerId.Visitor,
                homeDamage,
                visitorDamage
            );
            emit RoundCompleted(
                numRounds,
                true,
                PlayerId.Home,
                PlayerId.Visitor,
                homeDamage,
                visitorDamage
            );
        }

        // Increment the round number.
        numRounds++;
        uint8 homeWinCount = _winCount(PlayerId.Home);
        uint8 visitorWinCount = _winCount(PlayerId.Visitor);

        uint8 diffWinCount = homeWinCount > visitorWinCount
            ? homeWinCount - visitorWinCount
            : visitorWinCount - homeWinCount;

        // Check whether the battle round continues or not.
        if (
            numRounds == MAX_ROUNDS || diffWinCount > (MAX_ROUNDS - numRounds)
        ) {
            // This battle ends.
            battleState = BattleState.RoundSettled;
            _settleBattle();

            // Check draw condition.
            bool isDraw = homeWinCount == visitorWinCount;

            PlayerId winner = homeWinCount >= visitorWinCount
                ? PlayerId.Home
                : PlayerId.Visitor;
            PlayerId loser = _enemyId(winner);
            uint8 winnerCount = _winCount(winner);
            uint8 loserCount = _winCount(loser);

            battleResult = BattleResult(
                numRounds - 1,
                isDraw,
                winner,
                loser,
                winnerCount,
                loserCount
            );
            emit BattleCompleted(
                numRounds - 1,
                isDraw,
                winner,
                loser,
                winnerCount,
                loserCount
            );
            return;
        }

        // Reset the player states.
        playerInfoTable[PlayerId.Home].state = PlayerState.Standby;
        playerInfoTable[PlayerId.Visitor].state = PlayerState.Standby;

        // Set the block number when the next round starts.
        choiceCommitFromBlocks[numRounds] = block.number;
    }

    /// @notice Function to deal with cheater and cancel battle.
    /// @dev 1. Ban the account (subtract constant block number from the
    ///         subscribing period limit.)
    ///      2. Refund stamina for the enemy honest player.
    ///      3. Cancel this battle.
    function _dealWithCheaterAndCancelBattle(PlayerId playerId) internal {
        // Reduce the subscribing period to ban the cheater account.
        dealer.banAccount(
            _playerAddr(playerId),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_CHEATER
        );

        // Refund stamina for the enemy player.
        dealer.refundStaminaForBattle(_playerAddr(_enemyId(playerId)));

        // Cancel battle because of cheat detection.
        _cancelBattle();
    }

    /// @notice Function to deal with delayer and cancel battle.
    /// @dev 1. Ban the account (subtract constant block number from the
    ///         subscribing period limit.)
    ///      2. Refund stamina for the enemy honest player.
    ///      3. Cancel this battle.
    function _dealWithDelayerAndCancelBattle(PlayerId playerId) internal {
        // Reduce the subscribing period to ban the delayer's account.
        dealer.banAccount(
            _playerAddr(playerId),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );

        // Refund stamina for the enemy player.
        dealer.refundStaminaForBattle(_playerAddr(_enemyId(playerId)));

        // Cancel battle because of delay detection.
        _cancelBattle();
    }

    /// @notice Function to deal with the case that both players are delayers.
    /// @dev 1. Ban both accounts (subtract constant block number from the
    ///         subscribing period limit.)
    ///      2. Cancel this battle without stamina refunding.
    function _dealWithDelayersAndCancelBattle() internal {
        // Reduce the subscribing period to ban both players' accounts.
        dealer.banAccount(
            _playerAddr(PlayerId.Home),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );
        dealer.banAccount(
            _playerAddr(PlayerId.Visitor),
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );

        // Cancel battle because of delay detection.
        _cancelBattle();
    }

    /// @notice Core logic to finalization of the battle.
    function _settleBattle() internal {
        uint8 homeWinCount = _winCount(PlayerId.Home);
        uint8 visitorWinCount = _winCount(PlayerId.Visitor);

        // Pay rewards (PLMCoin) to the winner from dealer.
        if (homeWinCount > visitorWinCount) {
            // home Wins !!
            _payRewards(PlayerId.Home, PlayerId.Visitor);
        } else if (homeWinCount < visitorWinCount) {
            // visitor Wins !!
            _payRewards(PlayerId.Visitor, PlayerId.Home);
        } else {
            _payRewardsDraw();
        }

        // Update the proposal state.
        matchOrganizer.resetMatchStates(
            playerInfoTable[PlayerId.Home].addr,
            playerInfoTable[PlayerId.Visitor].addr
        );

        // settle this battle.
        battleState = BattleState.Settled;
    }

    /// @notice Function to cancel this battle.
    function _cancelBattle() internal {
        // TODO: modify here when we implement multislot battle.
        matchOrganizer.resetMatchStates(
            playerInfoTable[PlayerId.Home].addr,
            playerInfoTable[PlayerId.Visitor].addr
        );
        battleState = BattleState.Canceled;

        emit BattleCanceled();
    }

    /// @notice Function to pay reward to the winner.
    /// @dev This logic is derived from Pokemon.
    function _payRewards(PlayerId winner, PlayerId loser) internal {
        // Calculate the reward balance of the winner.
        uint16 winnerTotalLevel = _totalLevel(winner);
        uint16 loserTotalLevel = _totalLevel(loser);

        // Pokemon inspired reward calculation.
        uint48 top = 51 *
            uint48(loserTotalLevel) *
            (uint48(loserTotalLevel) * 2 + 102)**3;
        uint48 bottom = (uint48(winnerTotalLevel) +
            uint48(loserTotalLevel) +
            102)**3;

        // Dealer pay rewards to the winner.
        dealer.payReward(_playerAddr(winner), uint256(top / bottom));
    }

    /// @notice Function to pay reward to both players when draws.
    /// @dev This logic is derived from Pokemon.
    function _payRewardsDraw() internal {
        // Calculate the reward balance of both players.
        uint16 homeTotalLevel = _totalLevel(PlayerId.Home);
        uint16 visitorTotalLevel = _totalLevel(PlayerId.Visitor);

        // Pokemon inspired reward calculation.
        uint48 homeTop = 51 *
            uint48(homeTotalLevel) *
            (uint48(homeTotalLevel) * 2 + 102)**3;
        uint48 visitorTop = 51 *
            uint48(visitorTotalLevel) *
            (uint48(visitorTotalLevel) * 2 + 102)**3;
        uint48 bottom = (uint48(homeTotalLevel) +
            uint48(visitorTotalLevel) +
            102)**3;

        // The total amount of rewards are smaller then non-draw case.
        // Dealer pay rewards to both players.
        dealer.payReward(_playerAddr(PlayerId.Home), homeTop / bottom / 3);
        dealer.payReward(
            _playerAddr(PlayerId.Visitor),
            visitorTop / bottom / 3
        );
    }

    /// @notice Function to mark the slot used in the current round as used.
    /// @dev This function is called before step round.
    function _markSlot(PlayerId playerId) internal {
        Choice choice = choiceCommitLog[numRounds][playerId].choice;
        if (choice == Choice.Random) {
            playerInfoTable[playerId].randomSlot.usedRound = numRounds + 1;
        } else if (choice == Choice.Hidden) {
            revert("Unreachable!");
        } else {
            playerInfoTable[playerId].fixedSlotsUsedRounds[uint8(choice)] =
                numRounds +
                1;
        }
    }

    /// @notice Function to detect late playerSeed commitment.
    function _isLateForPlayerSeedCommit() internal view returns (bool) {
        return
            block.number >
            playerSeedCommitFromBlock + PLAYER_SEED_COMMIT_TIME_LIMIT;
    }

    /// @notice Function to detect late choice commitment.
    function _isLateForChoiceCommit() internal view returns (bool) {
        return
            block.number >
            choiceCommitFromBlocks[numRounds] + CHOICE_COMMIT_TIME_LIMIT;
    }

    /// @notice Function to detect late choice revealment.
    function _isLateForChoiceReveal() internal view returns (bool) {
        return
            block.number >
            choiceRevealFromBlocks[numRounds] + CHOICE_REVEAL_TIME_LIMIT;
    }

    /// @notice function to get enemy's playerId.
    function _enemyId(PlayerId playerId) internal pure returns (PlayerId) {
        return playerId == PlayerId.Home ? PlayerId.Visitor : PlayerId.Home;
    }

    /// @notice Function to calculate the total level of the fixed slots.
    /// @param playerId: The player's identifier.
    function _totalLevel(PlayerId playerId) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            totalLevel += token
                .getPriorCharacterInfo(
                    _fixedSlotTokenIdByIdx(playerId, slotIdx),
                    _fromBlock(playerId)
                )
                .level;
        }
        return totalLevel;
    }

    /// @notice Function to return the player's remainingLevelPoint.
    /// @param playerId: The player's identifier.
    function _remainingLevelPoint(PlayerId playerId)
        internal
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].remainingLevelPoint;
    }

    function _nonce(PlayerId playerId) internal view returns (bytes32) {
        require(
            _randomSlotState(playerId) != RandomSlotState.NotSet,
            "Nonce hasn't been set"
        );
        return playerInfoTable[playerId].randomSlot.nonce;
    }

    /// @notice Function to return the character information used in this round.
    /// @param playerId: The player's identifier.
    function _chosenCharacterInfo(PlayerId playerId)
        internal
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        Choice choice = choiceCommitLog[numRounds][playerId].choice;

        if (choice == Choice.Random) {
            // Player's choice is in a random slot.
            return _randomSlotCharInfo(playerId);
        } else if (choice == Choice.Hidden) {
            revert("Unreachable");
        } else {
            // Player's choice is in fixed slots.
            return _fixedSlotCharInfoByIdx(playerId, uint8(choice));
        }
    }

    function _totalSupplyAtFromBlock(PlayerId playerId)
        internal
        view
        returns (uint256)
    {
        // Here we assume that Bob is always a requester.
        return token.getPriorTotalSupply(_fromBlock(playerId));
    }

    function _randomSlotCharInfo(PlayerId playerId)
        internal
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        require(
            _randomSlotState(playerId) == RandomSlotState.Revealed,
            "playerSeed hasn't been revealed yet"
        );

        // Calculate the tokenId of random slot for player designated by PlayerId.
        uint256 tokenId = PLMSeeder.getRandomSlotTokenId(
            _nonce(playerId),
            _playerSeed(playerId),
            _totalSupplyAtFromBlock(playerId)
        );

        IPLMToken.CharacterInfo memory playerCharInfo = token
            .getPriorCharacterInfo(tokenId, _fromBlock(playerId));
        playerCharInfo.level = _randomSlotLevel(playerId);

        return playerCharInfo;
    }

    function _randomSlotState(PlayerId playerId)
        internal
        view
        returns (RandomSlotState)
    {
        return playerInfoTable[playerId].randomSlot.state;
    }

    function _randomSlotLevel(PlayerId playerId) internal view returns (uint8) {
        return playerInfoTable[playerId].randomSlot.level;
    }

    function _randomSlotIsUsed(PlayerId playerId) internal view returns (bool) {
        return _randomSlotUsedRound(playerId) > 0;
    }

    function _randomSlotUsedRound(PlayerId playerId)
        internal
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].randomSlot.usedRound;
    }

    function _winCount(PlayerId playerId) internal view returns (uint8) {
        return playerInfoTable[playerId].winCount;
    }

    function _playerSeed(PlayerId playerId) internal view returns (bytes32) {
        require(
            _randomSlotState(playerId) == RandomSlotState.Revealed,
            "playerSeed hasn't revealed yet"
        );
        return playerSeedCommitLog[playerId].playerSeed;
    }

    function _playerState(PlayerId playerId)
        internal
        view
        returns (PlayerState)
    {
        return playerInfoTable[playerId].state;
    }

    function _playerAddr(PlayerId playerId) internal view returns (address) {
        return playerInfoTable[playerId].addr;
    }

    function _fixedSlotTokenIdByIdx(PlayerId playerId, uint8 slotIdx)
        internal
        view
        returns (uint256)
    {
        require(slotIdx < FIXED_SLOTS_NUM, "Invalid fixed slot index");
        return playerInfoTable[playerId].fixedSlots[slotIdx];
    }

    function _fixedSlotOfIdxIsUsed(PlayerId playerId, uint8 slotIdx)
        internal
        view
        returns (bool)
    {
        return _fixedSlotUsedRoundByIdx(playerId, slotIdx) > 0;
    }

    function _fixedSlotUsedRoundByIdx(PlayerId playerId, uint8 slotIdx)
        internal
        view
        returns (uint8)
    {
        return playerInfoTable[playerId].fixedSlotsUsedRounds[slotIdx];
    }

    function _fromBlock(PlayerId playerId) internal view returns (uint256) {
        return playerInfoTable[playerId].fromBlock;
    }

    function _fixedSlotCharInfoByIdx(PlayerId playerId, uint8 slotIdx)
        internal
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        return
            token.getPriorCharacterInfo(
                _fixedSlotTokenIdByIdx(playerId, slotIdx),
                _fromBlock(playerId)
            );
    }

    //////////////////////////////
    /// BATTLE FIELD FUNCTIONS ///
    //////////////////////////////

    /// @notice Commit the player's seed to generate the tokenId for random slot.
    /// @param playerId: The player's identifier.
    /// @param commitString: commitment string calculated by the player designated by playerId
    ///                      as keccak256(abi.encodePacked(msg.sender, playerSeed)).
    function commitPlayerSeed(PlayerId playerId, bytes32 commitString)
        external
        nonReentrant
        onlyPlayerOf(playerId)
    {
        // Check that the battle hasn't started yet.
        require(
            battleState == BattleState.Standby,
            "Battle has already started."
        );

        // Check that the player seed hasn't set yet.
        require(
            _randomSlotState(playerId) == RandomSlotState.NotSet,
            "playerSeed has already been set."
        );

        PlayerId enemyId = _enemyId(playerId);

        // Check that player seed commitment is in time.
        if (_isLateForPlayerSeedCommit()) {
            emit LatePlayerSeedCommitDetected(playerId);

            if (_randomSlotState(enemyId) == RandomSlotState.NotSet) {
                // Both players are delayers.
                emit LatePlayerSeedCommitDetected(enemyId);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by playerId) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(playerId);
            }
            return;
        }

        // Save commitment on the storage. The playerSeed of the player is hidden in the commit phase.
        playerSeedCommitLog[playerId] = PlayerSeedCommit(
            commitString,
            bytes32(0)
        );

        // Emit the event that tells frontend that the player designated by playerId has committed.
        emit PlayerSeedCommitted(playerId);

        // Update the state of the random slot to be commited.
        playerInfoTable[playerId].randomSlot.state = RandomSlotState.Committed;

        // Generate nonce after player committed the playerSeed.
        bytes32 nonce = PLMSeeder.randomFromBlockHash();

        // Emit the event that tells frontend that the randomSlotNonce is generated for the player designated
        // by playerId.
        emit RandomSlotNounceGenerated(playerId, nonce);

        playerInfoTable[playerId].randomSlot.nonce = nonce;

        // If both players have already committed their player seeds, start the battle.
        if (_randomSlotState(enemyId) == RandomSlotState.Committed) {
            battleState = BattleState.InRound;
        }

        // Set the block number when the round starts.
        choiceCommitFromBlocks[numRounds] = block.number;
    }

    /// @param playerId: The player's identifier.
    /// @param playerSeed: the choice the player designated by playerId committed in this round.
    ///                    bytes32(0) is not allowed.
    function revealPlayerSeed(PlayerId playerId, bytes32 playerSeed)
        external
        inRound
        onlyPlayerOf(playerId)
        readyForPlayerSeedReveal(playerId)
    {
        // The pointer to the commit log of the player designated by playerId.
        PlayerSeedCommit storage playerSeedCommit = playerSeedCommitLog[
            playerId
        ];

        // Check the commit has coincides with the one stored on chain.
        require(
            keccak256(abi.encodePacked(msg.sender, playerSeed)) ==
                playerSeedCommit.commitString,
            "Commit hash doesn't coincide"
        );

        // Execute revealment
        playerSeedCommit.playerSeed = playerSeed;

        // Emit the event that tells frontend that the player designated by playerId has revealed.
        emit PlayerSeedRevealed(numRounds, playerId, playerSeed);

        // Update the state of the random slot to be revealed.
        playerInfoTable[playerId].randomSlot.state = RandomSlotState.Revealed;
    }

    /// @notice Commit the choice (the character the player choose to use in the current round).
    /// @param playerId: The player's identifier.
    /// @param commitString: commitment string calculated by the player designated by playerId
    ///                      as keccak256(abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor)).
    function commitChoice(PlayerId playerId, bytes32 commitString)
        external
        nonReentrant
        inRound
        onlyPlayerOf(playerId)
    {
        // Check that the player who want to commit haven't committed yet in this round.
        require(
            _playerState(playerId) == PlayerState.Standby,
            "Player isn't ready for choice commit"
        );

        PlayerId enemyId = _enemyId(playerId);

        // Check that choice commitment is in time.
        if (_isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(numRounds, playerId);

            if (_playerState(enemyId) == PlayerState.Standby) {
                // Both players are delayers.
                emit LateChoiceCommitDetected(numRounds, enemyId);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by playerId) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(playerId);
            }
            return;
        }

        // Save commitment on the storage. The choice of the player is hidden in the commit phase.
        choiceCommitLog[numRounds][playerId] = ChoiceCommit(
            commitString,
            0,
            Choice.Hidden
        );

        // Emit the event that tells frontend that the player designated by playerId has committed.
        emit ChoiceCommitted(numRounds, playerId);

        // Update the state of the commit player to be committed.
        playerInfoTable[playerId].state = PlayerState.Committed;

        if (_playerState(enemyId) == PlayerState.Committed) {
            // both players have already committed.
            choiceRevealFromBlocks[numRounds] = block.number;
        }
    }

    /// @notice Reveal the committed choice by the player who committed it in this round.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    /// @param playerId: The player's identifier.
    /// @param levelPoint: the levelPoint the player uses to the chosen character.
    /// @param choice: the choice the player designated by playerId committed in this round.
    ///                Choice.Hidden is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    function revealChoice(
        PlayerId playerId,
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    )
        external
        nonReentrant
        inRound
        onlyPlayerOf(playerId)
        readyForChoiceReveal(playerId)
    {
        // Choice.Hidden is not allowed for the choice passed to the reveal function.
        require(
            choice != Choice.Hidden,
            "Choice.Hidden isn't allowed when revealing"
        );

        PlayerId enemyId = _enemyId(playerId);

        // Check that choice revealment is in time.
        if (_isLateForChoiceReveal()) {
            emit LateChoiceRevealDetected(numRounds, playerId);

            if (_playerState(enemyId) == PlayerState.Committed) {
                // Both players are delayers.
                emit LateChoiceRevealDetected(numRounds, enemyId);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by playerId) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(playerId);
            }
            return;
        }

        // If the choice is the random slot, then random slot must have already been revealed.
        if (choice == Choice.Random) {
            require(
                _randomSlotState(playerId) == RandomSlotState.Revealed,
                "Random slot can't be used because playerSeed hasn't been revealed yet"
            );
        }

        // The pointer to the commit log of the player designated by playerId.
        ChoiceCommit storage choiceCommit = choiceCommitLog[numRounds][
            playerId
        ];

        // Check the commit hash coincides with the one stored on chain.
        require(
            keccak256(
                abi.encodePacked(msg.sender, levelPoint, choice, bindingFactor)
            ) == choiceCommit.commitString,
            "Commit hash doesn't coincide"
        );

        // Check that the levelPoint is less than or equal to the remainingLevelPoint.
        uint8 remainingLevelPoint = _remainingLevelPoint(playerId);
        if (levelPoint > remainingLevelPoint) {
            emit ExceedingLevelPointCheatDetected(
                playerId,
                remainingLevelPoint,
                levelPoint
            );

            // Deal with the chater (the player designated by playerId) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(playerId);
            return;
        }

        // Subtract revealed levelPoint from remainingLevelPoint
        playerInfoTable[playerId].remainingLevelPoint -= levelPoint;

        // Check that the chosen slot hasn't been used yet.
        // If the revealed slot has already used, then end this match and ban the player designated by playerId.
        if (
            (choice == Choice.Random && _randomSlotIsUsed(playerId)) ||
            (choice != Choice.Random &&
                _fixedSlotOfIdxIsUsed(playerId, uint8(choice)))
        ) {
            emit ReusingUsedSlotCheatDetected(playerId, choice);

            // Deal with the chater (the player designated by playerId) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(playerId);
            return;
        }

        // Execute revealment
        choiceCommit.levelPoint = levelPoint;
        choiceCommit.choice = choice;

        // Emit the event that tells frontend that the player designated by playerId has revealed.
        emit ChoiceRevealed(numRounds, playerId, levelPoint, choice);

        // Update the state of the reveal player to be Revealed.
        playerInfoTable[playerId].state = PlayerState.Revealed;

        // If both players have already revealed their choices, then proceed to the damage
        // calculation.
        if (_playerState(enemyId) == PlayerState.Revealed) {
            _stepRound();
        }
    }

    /// @notice Function to report enemy player for late revealment.
    /// @dev This function is prepared to deal with the case that one of the player
    ///      don't reveal his/her choice and it locked the battle forever.
    ///      In this case, if the enemy (honest) player report him/her after the
    ///      choice revealmenet timelimit, then the delayer will be banned,
    ///      the battle will be canceled, and the stamina of the honest player will
    ///      be refunded.
    /// @param playerId: The player's identifier.
    function reportLateReveal(PlayerId playerId)
        external
        inRound
        onlyPlayerOf(playerId)
    {
        PlayerId enemyId = _enemyId(playerId);

        // Detect enemy player's late revealment.
        require(
            _playerState(enemyId) == PlayerState.Committed &&
                _isLateForChoiceReveal(),
            "Reported player isn't late"
        );

        emit LateChoiceRevealDetected(numRounds, enemyId);

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(enemyId);
    }

    /// @notice Function to start the battle.
    /// @dev This function is called from match organizer.
    /// @param homeAddr: the address of the player assigned to home.
    /// @param visitorAddr: the address of the player assigned to visitor.
    /// @param homeFromBlock: the block number used to view home's characters' info.
    /// @param visitorFromBlock: the block number used to view visitor's characters' info.
    /// @param homeFixedSlots: tokenIds of home's fixed slots.
    /// @param visitorFixedSlots: tokenIds of visitor's fixed slots.
    function startBattle(
        address homeAddr,
        address visitorAddr,
        uint256 homeFromBlock,
        uint256 visitorFromBlock,
        uint256[4] memory homeFixedSlots,
        uint256[4] memory visitorFixedSlots
    ) external readyForBattleStart onlyMatchOrganizer {
        IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory homeCharInfos;
        IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory visitorCharInfos;

        // Retrieve character infomation by tokenId in the fixed slots.
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            homeCharInfos[slotIdx] = token.getPriorCharacterInfo(
                homeFixedSlots[slotIdx],
                homeFromBlock
            );
            visitorCharInfos[slotIdx] = token.getPriorCharacterInfo(
                visitorFixedSlots[slotIdx],
                visitorFromBlock
            );
        }

        // Get level point for both players.
        uint8 homeLevelPoint = token.getLevelPoint(homeCharInfos);
        uint8 visitorLevelPoint = token.getLevelPoint(visitorCharInfos);

        // Initialize both players' information.
        // Initialize random slots of them too.
        playerInfoTable[PlayerId.Home] = PlayerInfo(
            homeAddr,
            homeFromBlock,
            homeFixedSlots,
            [0, 0, 0, 0],
            RandomSlot(
                token.getRandomSlotLevel(homeCharInfos),
                bytes32(0),
                0,
                RandomSlotState.NotSet
            ),
            PlayerState.Standby,
            0,
            homeLevelPoint,
            homeLevelPoint
        );
        playerInfoTable[PlayerId.Visitor] = PlayerInfo(
            visitorAddr,
            visitorFromBlock,
            visitorFixedSlots,
            [0, 0, 0, 0],
            RandomSlot(
                token.getRandomSlotLevel(visitorCharInfos),
                bytes32(0),
                0,
                RandomSlotState.NotSet
            ),
            PlayerState.Standby,
            0,
            visitorLevelPoint,
            visitorLevelPoint
        );

        // Change battle state to wait for the playerSeed commitment.
        battleState = BattleState.Standby;

        // Set the block number when the battle has started.
        playerSeedCommitFromBlock = block.number;

        // Reset round number.
        numRounds = 0;

        emit BattleStarted(homeAddr, visitorAddr);
    }

    function playerSeedIsRevealed(PlayerId playerId)
        external
        view
        returns (bool)
    {
        return _randomSlotState(playerId) == RandomSlotState.Revealed;
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getBattleState() external view returns (BattleState) {
        return battleState;
    }

    function getPlayerState(PlayerId playerId)
        external
        view
        returns (PlayerState)
    {
        return _playerState(playerId);
    }

    function getRemainingLevelPoint(PlayerId playerId)
        external
        view
        returns (uint256)
    {
        return _remainingLevelPoint(playerId);
    }

    function getNonce(PlayerId playerId) external view returns (bytes32) {
        return _nonce(playerId);
    }

    function getFixedSlotCharInfo(PlayerId playerId)
        external
        view
        returns (IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory)
    {
        IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory playerCharInfos;
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            playerCharInfos[slotIdx] = _fixedSlotCharInfoByIdx(
                playerId,
                slotIdx
            );
        }

        return playerCharInfos;
    }

    function getVirtualRandomSlotCharInfo(PlayerId playerId, uint256 tokenId)
        external
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        IPLMToken.CharacterInfo memory virtualPlayerCharInfo = token
            .getPriorCharacterInfo(tokenId, _fromBlock(playerId));
        virtualPlayerCharInfo.level = _randomSlotLevel(playerId);

        return virtualPlayerCharInfo;
    }

    function getRandomSlotCharInfo(PlayerId playerId)
        external
        view
        returns (IPLMToken.CharacterInfo memory)
    {
        return _randomSlotCharInfo(playerId);
    }

    function getCharsUsedRounds(PlayerId playerId)
        external
        view
        returns (uint8[5] memory)
    {
        uint8[5] memory order;

        // Fixed slots
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            order[slotIdx] = _fixedSlotUsedRoundByIdx(playerId, slotIdx);
        }

        // Random slots
        order[4] = _randomSlotUsedRound(playerId);

        return order;
    }

    function getPlayerIdFromAddr(address playerAddr)
        external
        view
        returns (PlayerId)
    {
        bytes32 playerAddrBytes = keccak256(abi.encodePacked(playerAddr));
        bytes32 homeAddrBytes = keccak256(
            abi.encodePacked(playerInfoTable[PlayerId.Home].addr)
        );
        bytes32 visitorAddrBytes = keccak256(
            abi.encodePacked(playerInfoTable[PlayerId.Visitor].addr)
        );
        require(
            playerAddrBytes == homeAddrBytes ||
                playerAddrBytes == visitorAddrBytes,
            "The player designated by playerAddr is not in the battle."
        );
        return
            playerAddrBytes == homeAddrBytes ? PlayerId.Home : PlayerId.Visitor;
    }

    function getBondLevelAtBattleStart(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32)
    {
        return
            token.getPriorBondLevel(
                level,
                fromBlock,
                _fromBlock(PlayerId.Visitor)
            );
    }

    function getTotalSupplyAtFromBlock(PlayerId playerId)
        external
        view
        returns (uint256)
    {
        return _totalSupplyAtFromBlock(playerId);
    }

    /// @dev 0-indexed
    function getCurrentRound() external view returns (uint8) {
        return numRounds;
    }

    function getMaxLevelPoint(PlayerId playerId) external view returns (uint8) {
        return playerInfoTable[playerId].maxLevelPoint;
    }

    function getRoundResults() external view returns (RoundResult[] memory) {
        RoundResult[] memory results = new RoundResult[](numRounds + 1);
        for (uint256 i = 0; i < numRounds + 1; i++) {
            results[i] = roundResults[i];
        }
        return results;
    }

    function getBattleResult() external view returns (BattleResult memory) {
        return battleResult;
    }

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        returns (bool)
    {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPLMBattleField).interfaceId;
    }

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    /// @notice Function to set battle field contract's address as interface inside
    ///         this contract.
    /// @dev This contract and MatchOrganizer contract is referenced each other.
    ///      This is the reason why we have to prepare this function.
    ///      Given contract address, this function checks that the contract supports
    ///      IPLMMatchOrganizer interface. If so, set the address as interface.
    /// @param _matchOrganizer: the contract address of PLMMatchOrganizer contract.
    function setPLMMatchOrganizer(address _matchOrganizer)
        external
        onlyPolylemmers
    {
        require(
            IERC165(_matchOrganizer).supportsInterface(
                type(IPLMMatchOrganizer).interfaceId
            ),
            "Given contract doesn't support IPLMMatchOrganizer"
        );
        matchOrganizer = IPLMMatchOrganizer(_matchOrganizer);
    }

    //////////////////////////
    /// FUNCTIONS FOR DEMO ///
    //////////////////////////

    // FIXME: remove this function after demo.
    function forceInitBattle() external {
        battleState = BattleState.Settled;
        matchOrganizer.forceResetMatchState(_playerAddr(PlayerId.Home));
        matchOrganizer.forceResetMatchState(_playerAddr(PlayerId.Visitor));
    }
}
