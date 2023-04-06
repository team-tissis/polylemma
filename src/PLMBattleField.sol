// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {PLMSeeder} from "./lib/PLMSeeder.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "./interfaces/IPLMMatchOrganizer.sol";
import {IPLMBattleManager} from "./interfaces/IPLMBattleManager.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

contract PLMBattleField is IPLMBattleField, IERC165 {
    /// @notice for reentrancyGuard;
    /// @dev this constant is implemented as uint256 because it is inplemented in this manner in Openzeppelin
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

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
    /// TODO; 元に戻す
    uint256 constant PLAYER_SEED_COMMIT_TIME_LIMIT = 600;

    /// @notice The limit of commitment for each player. About 60 seconds.
    /// TODO; 元に戻す
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 600;

    /// @notice The limit of revealment for each player. About 30 seconds.
    /// TODO; 元に戻す
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 600;

    /// @notice interface to the dealer of polylemma.
    IPLMDealer dealer;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice interface to the database of polylemma.
    IPLMData data;

    /// @notice interface to the MatchOrganizer.
    IPLMMatchOrganizer matchOrganizer;

    /// @notice interface to the battleManager.
    IPLMBattleManager manager;

    /// @notice admin's address
    address polylemmers;

    /// @notice latest battle ID
    mapping(address => uint256) battleId;

    /// @notice latest enemy address
    mapping(address => address) enemyAddr;

    /// @notice status for reentrancy guard for each battle, battle Id => locked flag, _NOT_ENTERED or _ENTERED
    mapping(uint256 => uint256) private _status;

    constructor(
        IPLMDealer _dealer,
        IPLMToken _token,
        IPLMBattleManager _manager
    ) {
        dealer = _dealer;
        token = _token;
        manager = _manager;
        data = IPLMData(_token.getDataAddr());
        polylemmers = msg.sender;
    }

    modifier nonReentrantForEachBattle() {
        _nonReentrantForEachBattleBefore();
        _;
        _nonReentrantForEachBattleAfter();
    }

    /// @notice Check that the battle state is standby.
    modifier standby() {
        require(
            _battleState() == BattleState.Standby,
            "Battle state isn't standby yet"
        );
        _;
    }

    /// @notice Check that the battle round has already started.
    modifier inRound() {
        require(
            _battleState() == BattleState.InRound,
            "Battle round hasn't started yet"
        );
        _;
    }

    modifier onlyPlayerOf() {
        uint256 _battleId = battleId[msg.sender];
        BattleState battleState = manager.getBattleStateById(_battleId);
        require(
            _battleId == battleId[enemyAddr[msg.sender]] &&
                (battleState != BattleState.NotStarted ||
                    battleState != BattleState.Settled ||
                    battleState != BattleState.Canceled),
            "call invalid battle"
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

    /// @notice Check that the random slot of the player designated by player
    ///         has already been committed, the choice of that player in this
    ///         round is randomSlot, and it has already been revealed.
    modifier readyForPlayerSeedReveal() {
        // Prevent double revealing.
        require(
            _randomSlotState(msg.sender) == RandomSlotState.Committed,
            "playerSeed has already been revealed."
        );

        address _enemyAddr = enemyAddr[msg.sender];
        require(
            _playerState(msg.sender) == PlayerState.Committed &&
                (_playerState(_enemyAddr) == PlayerState.Committed ||
                    _playerState(_enemyAddr) == PlayerState.Revealed),
            "Home or Visitor hasn't committed one's choice yet"
        );
        _;
    }

    /// @notice Check that both players have already committed in this round.
    modifier readyForChoiceReveal() {
        require(
            _playerState(msg.sender) == PlayerState.Committed,
            "Player hasn't committed the choice yet"
        );

        address _enemyAddr = enemyAddr[msg.sender];
        PlayerState enemyState = _playerState(_enemyAddr);

        // If the enemy player has not committed yet and it's over commit time limit,
        // ban the enemy player as delayer.
        if (enemyState == PlayerState.Standby && _isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(
                battleId[msg.sender],
                manager.getNumRounds(msg.sender),
                _enemyAddr
            );

            // Deal with the delayer (the player designated by player) and cancel
            // this battle.
            _dealWithDelayerAndCancelBattle(msg.sender);
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

    function _nonReentrantForEachBattleBefore() private {
        uint256 _battleId = battleId[msg.sender];

        // On the first call to nonReentrantForEachBattle, _status will be _NOT_ENTERED
        require(
            _status[_battleId] != _ENTERED,
            "ReentrancyGuard: reentrant call"
        );

        // Any calls to nonReentrantForEachBattle after this point will fail
        _status[_battleId] = _ENTERED;
    }

    function _nonReentrantForEachBattleAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status[battleId[msg.sender]] = _NOT_ENTERED;
    }

    /// @notice Function to execute closing round.
    /// @dev This function is automatically called in the end of _stepRound
    function _endRound(
        uint32 winnerDamage,
        uint32 loserDamage,
        address winner,
        bool isDraw
    ) internal {
        address _enemyAddr = enemyAddr[winner];
        manager.incrementPlayerInfoWinCount(winner);
        manager.setRoundResult(
            msg.sender,
            RoundResult(isDraw, winner, _enemyAddr, winnerDamage, loserDamage)
        );
        emit RoundCompleted(
            battleId[msg.sender],
            manager.getNumRounds(msg.sender),
            isDraw,
            winner,
            _enemyAddr,
            winnerDamage,
            loserDamage
        );
    }

    /// @notice Function to execute the current round.
    /// @dev This function is automatically called after both players' choice revealment
    ///      of this round.
    function _stepRound() internal {
        // Mark the slot as used.
        _markSlot(msg.sender);
        address _enemyAddr = enemyAddr[msg.sender];
        _markSlot(_enemyAddr);

        // Calculate the damage of both players.
        // Minimalize character info
        IPLMData.CharacterInfoMinimal memory myChar = _chosenCharacterInfo(
            msg.sender
        );
        IPLMData.CharacterInfoMinimal memory enemyChar = _chosenCharacterInfo(
            _enemyAddr
        );

        uint8 numRounds = manager.getNumRounds(msg.sender);

        /// @notice this {} to avoid stacking to deep error
        {
            uint32 myDamage = data.getDamage(
                numRounds,
                myChar,
                manager.getChoiceCommitLevelPoint(msg.sender),
                manager.getBondLevelAtBattleStart(
                    msg.sender,
                    myChar.level,
                    myChar.fromBlock
                ),
                enemyChar
            );

            uint32 enemyDamage = data.getDamage(
                numRounds,
                enemyChar,
                manager.getChoiceCommitLevelPoint(_enemyAddr),
                manager.getBondLevelAtBattleStart(
                    msg.sender,
                    myChar.level,
                    myChar.fromBlock
                ),
                myChar
            );

            // Judge the battle result of this round.
            if (myDamage > enemyDamage) {
                // home wins !!
                _endRound(myDamage, enemyDamage, msg.sender, false);
            } else if (myDamage < enemyDamage) {
                // visitor wins !!
                _endRound(enemyDamage, myDamage, _enemyAddr, false);
            } else {
                // Draw !!
                _endRound(myDamage, enemyDamage, msg.sender, true);
            }
        }

        // Increment the round number.
        manager.incrementNumRounds(msg.sender);
        numRounds++;

        uint8 myWinCount = _winCount(msg.sender);
        uint8 enemyWinCount = _winCount(_enemyAddr);

        uint8 diffWinCount = myWinCount > enemyWinCount
            ? myWinCount - enemyWinCount
            : enemyWinCount - myWinCount;

        // Check whether the battle round continues or not.
        if (
            numRounds == MAX_ROUNDS || diffWinCount > (MAX_ROUNDS - numRounds)
        ) {
            manager.setBattleState(msg.sender, BattleState.RoundSettled);

            // Check draw condition.
            bool isDraw = myWinCount == enemyWinCount;

            address winner = myWinCount >= enemyWinCount
                ? msg.sender
                : _enemyAddr;
            address loser = _enemyAddr;
            uint8 winnerCount = _winCount(winner);
            uint8 loserCount = _winCount(loser);

            manager.setBattleResult(
                msg.sender,
                BattleResult(
                    numRounds - 1,
                    isDraw,
                    winner,
                    loser,
                    winnerCount,
                    loserCount
                )
            );

            // This battle ends.
            _settleBattle();

            emit BattleCompleted(
                battleId[msg.sender],
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
        manager.setPlayerInfoState(msg.sender, PlayerState.Standby);
        manager.setPlayerInfoState(_enemyAddr, PlayerState.Standby);

        // Set the block number when the next round starts.
        manager.setCommitFromBlock(msg.sender, block.number);
    }

    /// @notice Function to deal with cheater and cancel battle.
    /// @dev 1. Ban the account (subtract constant block number from the
    ///         subscribing period limit.)
    ///      2. Refund stamina for the enemy honest player.
    ///      3. Cancel this battle.
    function _dealWithCheaterAndCancelBattle(address player) internal {
        // Reduce the subscribing period to ban the cheater account.
        dealer.banAccount(
            player,
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_CHEATER
        );

        // Refund stamina for the enemy player.
        dealer.refundStaminaForBattle(enemyAddr[msg.sender]);

        // Cancel battle because of cheat detection.
        _cancelBattle();
    }

    /// @notice Function to deal with delayer and cancel battle.
    /// @dev 1. Ban the account (subtract constant block number from the
    ///         subscribing period limit.)
    ///      2. Refund stamina for the enemy honest player.
    ///      3. Cancel this battle.
    function _dealWithDelayerAndCancelBattle(address player) internal {
        // Reduce the subscribing period to ban the delayer's account.
        dealer.banAccount(
            player,
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );

        // Refund stamina for the enemy player.
        dealer.refundStaminaForBattle(enemyAddr[msg.sender]);

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
            msg.sender,
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );
        dealer.banAccount(
            enemyAddr[msg.sender],
            DAILY_BLOCK_NUM * BAN_DATE_LENGTH_FOR_DELAYER_ACCOUNT
        );

        // Cancel battle because of delay detection.
        _cancelBattle();
    }

    /// @notice Core logic to finalization of the battle.
    function _settleBattle() internal {
        BattleResult memory br = manager.getBattleResult(msg.sender);
        if (br.isDraw) {
            // this battle is draw. pay rewards to both of players from dealer.
            _payRewardsDraw();
        } else {
            // Pay rewards (PLMCoin) to the winner from dealer.
            _payRewards(br.winner, br.loser);
        }

        // Update the proposal state.
        matchOrganizer.resetMatchStates(msg.sender, enemyAddr[msg.sender]);

        // settle this battle.
        manager.setBattleState(msg.sender, BattleState.Settled);
    }

    /// @notice Function to cancel this battle.
    function _cancelBattle() internal {
        matchOrganizer.resetMatchStates(msg.sender, enemyAddr[msg.sender]);
        manager.setBattleState(msg.sender, BattleState.Canceled);

        emit BattleCanceled(battleId[msg.sender]);
    }

    /// @notice Function to pay reward to the winner.
    /// @dev This logic is derived from Pokemon.
    function _payRewards(address winner, address loser) internal {
        // Calculate the reward balance of the winner.
        uint16 winnerTotalLevel = _totalLevel(winner);
        uint16 loserTotalLevel = _totalLevel(loser);

        // Pokemon inspired reward calculation.
        uint48 top = 51 *
            uint48(loserTotalLevel) *
            (uint48(loserTotalLevel) * 2 + 102) ** 3;
        uint48 bottom = (uint48(winnerTotalLevel) +
            uint48(loserTotalLevel) +
            102) ** 3;

        // Dealer pay rewards to the winner.
        dealer.payReward(winner, uint256(top / bottom));
    }

    /// @notice Function to pay reward to both players when draws.
    /// @dev This logic is derived from Pokemon.
    function _payRewardsDraw() internal {
        address _enemyAddr = enemyAddr[msg.sender];
        // Calculate the reward balance of both players.
        uint16 myTotalLevel = _totalLevel(msg.sender);
        uint16 enemyTotalLevel = _totalLevel(_enemyAddr);

        // Pokemon inspired reward calculation.
        uint48 homeTop = 51 *
            uint48(myTotalLevel) *
            (uint48(myTotalLevel) * 2 + 102) ** 3;
        uint48 visitorTop = 51 *
            uint48(enemyTotalLevel) *
            (uint48(enemyTotalLevel) * 2 + 102) ** 3;
        uint48 bottom = (uint48(myTotalLevel) +
            uint48(enemyTotalLevel) +
            102) ** 3;

        // The total amount of rewards are smaller then non-draw case.
        // Dealer pay rewards to both players.
        dealer.payReward(msg.sender, homeTop / bottom / 3);
        dealer.payReward(_enemyAddr, visitorTop / bottom / 3);
    }

    /// @notice Function to mark the slot used in the current round as used.
    /// @dev This function is called before step round.
    function _markSlot(address player) internal {
        uint8 numRounds = manager.getNumRounds(player);
        Choice choice = manager.getChoiceCommitChoice(player);
        if (choice == Choice.Random) {
            manager.setPlayerInfoRandomSlotUsedRound(player, numRounds + 1);
        } else if (choice == Choice.Hidden) {
            revert("Unreachable!");
        } else {
            manager.setPlayerInfoFixedSlotUsedRound(
                player,
                uint8(choice),
                numRounds + 1
            );
        }
    }

    /// TODO:　それとも正常にコミットできた後この関数を呼んだとしても遅れていることになる。
    /// @notice Function to detect late playerSeed commitment.
    function _isLateForPlayerSeedCommit() internal view returns (bool) {
        return
            block.number >
            manager.getPlayerSeedCommitFromBlock(msg.sender) +
                PLAYER_SEED_COMMIT_TIME_LIMIT;
    }

    /// @notice Function to detect late choice commitment.
    function _isLateForChoiceCommit() internal view returns (bool) {
        return
            block.number >
            manager.getCommitFromBlock(msg.sender) + CHOICE_COMMIT_TIME_LIMIT;
    }

    /// @notice Function to detect late choice revealment.
    function _isLateForChoiceReveal() internal view returns (bool) {
        return
            block.number >
            manager.getRevealFromBlock(msg.sender) + CHOICE_REVEAL_TIME_LIMIT;
    }

    /// @notice Function to calculate the total level of the fixed slots.
    /// @param player: The player's address
    function _totalLevel(address player) internal view returns (uint16) {
        uint16 totalLevel = 0;
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            totalLevel += _fixedSlotCharInfoByIdx(player, slotIdx).level;
        }
        return totalLevel;
    }

    function _battleState()
        internal
        view
        returns (IPLMBattleField.BattleState)
    {
        return manager.getBattleState(msg.sender);
    }

    /// @notice Function to return the player's remainingLevelPoint.
    /// @param player: The player's address.
    function _remainingLevelPoint(
        address player
    ) internal view returns (uint8) {
        return manager.getPlayerInfoRemainingLevelPoint(msg.sender);
    }

    function _nonce(address player) internal view returns (bytes32) {
        require(
            _randomSlotState(player) != RandomSlotState.NotSet,
            "Nonce hasn't been set"
        );
        return manager.getPlayerInfoRandomSlotNonce(msg.sender);
    }

    /// @notice Function to return the character information used in this round.
    /// @param player: The player's address.
    function _chosenCharacterInfo(
        address player
    ) internal view returns (IPLMData.CharacterInfoMinimal memory) {
        Choice choice = manager.getChoiceCommitChoice(player);

        if (choice == Choice.Random) {
            // Player's choice is in a random slot.
            return token.minimalizeCharInfo(_randomSlotCharInfo(player));
        } else if (choice == Choice.Hidden) {
            revert("Unreachable");
        } else {
            // Player's choice is in fixed slots.
            return
                token.minimalizeCharInfo(
                    _fixedSlotCharInfoByIdx(player, uint8(choice))
                );
        }
    }

    // TODO:これはこのコントラクトにgetterを書く
    function _randomSlotCharInfo(
        address player
    ) internal view returns (IPLMToken.CharacterInfo memory) {
        require(
            _randomSlotState(player) == RandomSlotState.Revealed,
            "playerSeed hasn't been revealed yet"
        );

        // Calculate the tokenId of random slot for player designated by player.
        uint256 tokenId = PLMSeeder.getRandomSlotTokenId(
            _nonce(player),
            _playerSeed(player),
            manager.getTotalSupplyAtFromBlock(player)
        );

        IPLMToken.CharacterInfo memory playerCharInfo = token
            .getPriorCharacterInfo(tokenId, _fromBlock(player));
        playerCharInfo.level = _randomSlotLevel(player);

        return playerCharInfo;
    }

    function _randomSlotState(
        address player
    ) internal view returns (RandomSlotState) {
        return manager.getPlayerInfoRandomSlotState(player);
    }

    function _randomSlotLevel(address player) internal view returns (uint8) {
        return manager.getPlayerInfoRandomSlotLevel(player);
    }

    function _randomSlotUsedRound(
        address player
    ) internal view returns (uint8) {
        return manager.getPlayerInfoRandomSlotUsedRound(player);
    }

    function _winCount(address player) internal view returns (uint8) {
        return manager.getPlayerInfoWinCount(player);
    }

    function _playerSeed(address player) internal view returns (bytes32) {
        require(
            _randomSlotState(player) == RandomSlotState.Revealed,
            "playerSeed hasn't revealed yet"
        );
        return manager.getPlayerSeedCommit(player).playerSeed;
    }

    function _playerState(address player) internal view returns (PlayerState) {
        return manager.getPlayerInfoPlayerState(player);
    }

    function _fixedSlotTokenIdByIdx(
        address player,
        uint8 slotIdx
    ) internal view returns (uint256) {
        require(slotIdx < FIXED_SLOTS_NUM, "Invalid fixed slot index");
        return manager.getPlayerInfoFixedSlots(player)[slotIdx];
    }

    function _fixedSlotUsedRoundByIdx(
        address player,
        uint8 slotIdx
    ) internal view returns (uint8) {
        return manager.getPlayerInfoFixedSlotsUsedRounds(player)[slotIdx];
    }

    function _fromBlock(address player) internal view returns (uint256) {
        return manager.getPlayerInfoFromBlock(player);
    }

    function _fixedSlotCharInfoByIdx(
        address player,
        uint8 slotIdx
    ) internal view returns (IPLMToken.CharacterInfo memory) {
        return
            token.getPriorCharacterInfo(
                _fixedSlotTokenIdByIdx(player, slotIdx),
                _fromBlock(player)
            );
    }

    //////////////////////////////
    /// BATTLE FIELD FUNCTIONS ///
    //////////////////////////////

    /// @notice Commit the player's seed to generate the tokenId for random slot.
    /// @param commitString: commitment string calculated by the player designated by player
    ///                      as keccak256(abi.encodePacked(msg.sender, playerSeed)).
    function commitPlayerSeed(
        bytes32 commitString
    ) external nonReentrantForEachBattle onlyPlayerOf {
        // Check that the battle hasn't started yet.
        require(
            _battleState() == BattleState.Standby,
            "Battle has already started."
        );
        address _enemyAddr = enemyAddr[msg.sender];
        // Check that the player seed hasn't set yet.
        require(
            _randomSlotState(msg.sender) == RandomSlotState.NotSet,
            "playerSeed has already been set."
        );

        uint256 _battleId = battleId[msg.sender];
        // Check that player seed commitment is in time.
        if (_isLateForPlayerSeedCommit()) {
            emit LatePlayerSeedCommitDetected(_battleId, msg.sender);

            if (_randomSlotState(_enemyAddr) == RandomSlotState.NotSet) {
                // Both players are delayers.
                emit LatePlayerSeedCommitDetected(_battleId, _enemyAddr);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by player) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(msg.sender);
            }
            return;
        }

        // Save commitment on the storage. The playerSeed of the player is hidden in the commit phase.
        manager.setPlayerSeedCommit(
            msg.sender,
            PlayerSeedCommit(commitString, bytes32(0))
        );

        // Emit the event that tells frontend that the player designated by player has committed.
        emit PlayerSeedCommitted(_battleId, msg.sender);

        // Update the state of the random slot to be commited.
        manager.setPlayerInfoRandomSlotState(
            msg.sender,
            RandomSlotState.Committed
        );

        // Generate nonce after player committed the playerSeed.
        bytes32 nonce = PLMSeeder.randomFromBlockHash();

        // Emit the event that tells frontend that the randomSlotNonce is generated for the player designated
        // by player.
        emit RandomSlotNounceGenerated(_battleId, msg.sender, nonce);

        manager.setPlayerInfoRandomSlotNonce(msg.sender, nonce);

        // If both players have already committed their player seeds, start the battle.
        if (_randomSlotState(_enemyAddr) == RandomSlotState.Committed) {
            manager.setBattleState(msg.sender, BattleState.InRound);
        }

        // Set the block number when the round starts.
        manager.setCommitFromBlock(msg.sender, block.number);
    }

    /// @param playerSeed: the choice the player designated by player committed in this round.
    ///                    bytes32(0) is not allowed.
    function revealPlayerSeed(
        bytes32 playerSeed
    ) external inRound readyForPlayerSeedReveal onlyPlayerOf {
        // The pointer to the commit log of the player designated by player.
        PlayerSeedCommit memory playerSeedCommit = manager.getPlayerSeedCommit(
            msg.sender
        );

        // Check the commit has coincides with the one stored on chain.
        require(
            keccak256(abi.encodePacked(msg.sender, playerSeed)) ==
                playerSeedCommit.commitString,
            "Commit hash doesn't coincide"
        );

        // Execute revealment
        manager.setPlayerSeedCommitValue(msg.sender, playerSeed);

        // Emit the event that tells frontend that the player designated by player has revealed.
        emit PlayerSeedRevealed(
            battleId[msg.sender],
            manager.getNumRounds(msg.sender),
            msg.sender,
            playerSeed
        );

        // Update the state of the random slot to be revealed.
        manager.setPlayerInfoRandomSlotState(
            msg.sender,
            RandomSlotState.Revealed
        );
    }

    /// @notice Commit the choice (the character the player choose to use in the current round).
    /// @param commitString: commitment string calculated by the player designated by player
    ///                      as keccak256(abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor)).
    function commitChoice(
        bytes32 commitString
    ) external nonReentrantForEachBattle inRound onlyPlayerOf {
        // Check that the player who want to commit haven't committed yet in this round.
        require(
            _playerState(msg.sender) == PlayerState.Standby,
            "Player isn't ready for choice commit"
        );
        address _enemyAddr = enemyAddr[msg.sender];

        uint8 numRounds = manager.getNumRounds(msg.sender);
        uint256 _battleId = battleId[msg.sender];
        // Check that choice commitment is in time.
        if (_isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(_battleId, numRounds, msg.sender);

            if (_playerState(_enemyAddr) == PlayerState.Standby) {
                // Both players are delayers.
                emit LateChoiceCommitDetected(_battleId, numRounds, _enemyAddr);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by player) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(msg.sender);
            }
            return;
        }

        // Save commitment on the storage. The choice of the player is hidden in the commit phase.
        manager.setChoiceCommit(
            msg.sender,
            ChoiceCommit(commitString, 0, Choice.Hidden)
        );

        // Emit the event that tells frontend that the player designated by player has committed.
        emit ChoiceCommitted(_battleId, numRounds, msg.sender);

        // Update the state of the commit player to be committed.
        manager.setPlayerInfoState(msg.sender, PlayerState.Committed);

        if (_playerState(_enemyAddr) == PlayerState.Committed) {
            // both players have already committed.
            manager.setRevealFromBlock(msg.sender, block.number);
        }
    }

    /// @notice Reveal the committed choice by the player who committed it in this round.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    /// @param levelPoint: the levelPoint the player uses to the chosen character.
    /// @param choice: the choice the player designated by player committed in this round.
    ///                Choice.Hidden is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    function revealChoice(
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    )
        external
        nonReentrantForEachBattle
        inRound
        onlyPlayerOf
        readyForChoiceReveal
    {
        uint8 numRounds = manager.getNumRounds(msg.sender);
        // Choice.Hidden is not allowed for the choice passed to the reveal function.
        require(
            choice != Choice.Hidden,
            "Choice.Hidden isn't allowed when revealing"
        );
        address _enemyAddr = enemyAddr[msg.sender];
        uint256 _battleId = battleId[msg.sender];
        {
            // Check that choice revealment is in time.
            if (_isLateForChoiceReveal()) {
                emit LateChoiceRevealDetected(_battleId, numRounds, msg.sender);

                if (_playerState(_enemyAddr) == PlayerState.Committed) {
                    // Both players are delayers.
                    emit LateChoiceRevealDetected(
                        _battleId,
                        numRounds,
                        _enemyAddr
                    );
                    _dealWithDelayersAndCancelBattle();
                } else {
                    // Deal with the delayer (the player designated by player) and
                    // cancel this battle.
                    _dealWithDelayerAndCancelBattle(msg.sender);
                }
                return;
            }
        }

        // If the choice is the random slot, then random slot must have already been revealed.
        if (choice == Choice.Random) {
            require(
                _randomSlotState(msg.sender) == RandomSlotState.Revealed,
                "Random slot can't be used because playerSeed hasn't been revealed yet"
            );
        }

        // The pointer to the commit log of the player designated by player.
        bytes32 choiceCommitString = manager.getChoiceCommitString(msg.sender);

        // Check the commit hash coincides with the one stored on chain.
        require(
            keccak256(
                abi.encodePacked(msg.sender, levelPoint, choice, bindingFactor)
            ) == choiceCommitString,
            "Commit hash doesn't coincide"
        );

        // Check that the levelPoint is less than or equal to the remainingLevelPoint.
        uint8 remainingLevelPoint = _remainingLevelPoint(msg.sender);
        if (levelPoint > remainingLevelPoint) {
            emit ExceedingLevelPointCheatDetected(
                _battleId,
                msg.sender,
                remainingLevelPoint,
                levelPoint
            );

            // Deal with the chater (the player designated by player) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(msg.sender);
            return;
        }

        // Subtract revealed levelPoint from remainingLevelPoint
        manager.subtractPlayerInfoRemainingLevelPoint(msg.sender, levelPoint);

        // Check that the chosen slot hasn't been used yet.
        // If the revealed slot has already used, then end this match and ban the player designated by player.
        if (
            (choice == Choice.Random && _randomSlotUsedRound(msg.sender) > 0) ||
            (choice != Choice.Random &&
                _fixedSlotUsedRoundByIdx(msg.sender, uint8(choice)) > 0)
        ) {
            emit ReusingUsedSlotCheatDetected(_battleId, msg.sender, choice);

            // Deal with the chater (the player designated by player) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(msg.sender);
            return;
        }

        // Execute revealment
        manager.setChoiceCommitLevelPoint(msg.sender, levelPoint);
        manager.setChoiceCommitChoice(msg.sender, choice);

        // Emit the event that tells frontend that the player designated by player has revealed.
        emit ChoiceRevealed(
            _battleId,
            numRounds,
            msg.sender,
            levelPoint,
            choice
        );

        // Update the state of the reveal player to be Revealed.
        manager.setPlayerInfoState(msg.sender, PlayerState.Revealed);

        // If both players have already revealed their choices, then proceed to the damage
        // calculation.
        if (_playerState(_enemyAddr) == PlayerState.Revealed) {
            _stepRound();
        }
    }

    /// @notice Function to report enemy player for late Seed Commit.
    function reportLatePlayerSeedCommit() external standby onlyPlayerOf {
        // Detect enemy player's late player seed commit.
        address _enemyAddr = enemyAddr[msg.sender];
        require(
            _randomSlotState(_enemyAddr) == RandomSlotState.NotSet &&
                _isLateForPlayerSeedCommit(),
            "Reported player isn't late"
        );

        emit LatePlayerSeedCommitDetected(battleId[msg.sender], _enemyAddr);

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddr);
    }

    /// @notice Function to report enemy player for late commitment.
    function reportLateChoiceCommit() external inRound onlyPlayerOf {
        address _enemyAddr = enemyAddr[msg.sender];
        // Detect enemy player's late choice commit.
        require(
            _playerState(_enemyAddr) == PlayerState.Standby &&
                _isLateForChoiceCommit(),
            "Reported player isn't late"
        );

        emit LateChoiceCommitDetected(
            battleId[msg.sender],
            manager.getNumRounds(msg.sender),
            _enemyAddr
        );

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddr);
    }

    /// @notice Function to report enemy player for late revealment.
    /// @dev This function is prepared to deal with the case that one of the player
    ///      don't reveal his/her choice and it locked the battle forever.
    ///      In this case, if the enemy (honest) player report him/her after the
    ///      choice revealmenet timelimit, then the delayer will be banned,
    ///      the battle will be canceled, and the stamina of the honest player will
    ///      be refunded.
    function reportLateReveal() external inRound onlyPlayerOf {
        address _enemyAddr = enemyAddr[msg.sender];
        // Detect enemy player's late revealment.
        require(
            _playerState(_enemyAddr) == PlayerState.Committed &&
                _isLateForChoiceReveal(),
            "Reported player isn't late"
        );

        emit LateChoiceRevealDetected(
            battleId[msg.sender],
            manager.getNumRounds(msg.sender),
            _enemyAddr
        );

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddr);
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
    ) external onlyMatchOrganizer {
        manager.beforeBattleStart(homeAddr, visitorAddr);
        enemyAddr[homeAddr] = visitorAddr;
        enemyAddr[visitorAddr] = homeAddr;

        // register this battle to battle manager

        battleId[homeAddr] = manager.getLatestBattle(homeAddr);
        battleId[visitorAddr] = manager.getLatestBattle(visitorAddr);
        require(
            battleId[homeAddr] == battleId[visitorAddr],
            "battleIds don't match"
        );
        IPLMData.CharacterInfoMinimal[FIXED_SLOTS_NUM] memory homeCharInfos;
        IPLMData.CharacterInfoMinimal[FIXED_SLOTS_NUM] memory visitorCharInfos;

        // Retrieve character infomation by tokenId in the fixed slots.
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            homeCharInfos[slotIdx] = token.minimalizeCharInfo(
                token.getPriorCharacterInfo(
                    homeFixedSlots[slotIdx],
                    homeFromBlock
                )
            );
            visitorCharInfos[slotIdx] = token.minimalizeCharInfo(
                token.getPriorCharacterInfo(
                    visitorFixedSlots[slotIdx],
                    visitorFromBlock
                )
            );
        }

        {
            // Get level point for both players.
            uint8 homeLevelPoint = data.getLevelPoint(homeCharInfos);

            // Initialize both players' information.
            // Initialize random slots of them too.
            manager.setPlayerInfo(
                homeAddr,
                PlayerInfo(
                    homeAddr,
                    homeFromBlock,
                    homeFixedSlots,
                    [0, 0, 0, 0],
                    RandomSlot(
                        data.getRandomSlotLevel(homeCharInfos),
                        bytes32(0),
                        0,
                        RandomSlotState.NotSet
                    ),
                    PlayerState.Standby,
                    0,
                    homeLevelPoint,
                    homeLevelPoint
                )
            );
        }
        {
            uint8 visitorLevelPoint = data.getLevelPoint(visitorCharInfos);
            manager.setPlayerInfo(
                visitorAddr,
                PlayerInfo(
                    visitorAddr,
                    visitorFromBlock,
                    visitorFixedSlots,
                    [0, 0, 0, 0],
                    RandomSlot(
                        data.getRandomSlotLevel(visitorCharInfos),
                        bytes32(0),
                        0,
                        RandomSlotState.NotSet
                    ),
                    PlayerState.Standby,
                    0,
                    visitorLevelPoint,
                    visitorLevelPoint
                )
            );
        }

        // Change battle state to wait for the playerSeed commitment.
        manager.setBattleState(homeAddr, BattleState.Standby);

        // Set the block number when the battle has started.
        manager.setPlayerSeedCommitFromBlock(homeAddr, block.number);

        // Reset round number.
        manager.setNumRounds(homeAddr, 0);

        emit BattleStarted(battleId[msg.sender], homeAddr, visitorAddr);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPLMBattleField).interfaceId;
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getRandomSlotCharInfo(
        address player
    ) external view returns (IPLMToken.CharacterInfo memory) {
        return _randomSlotCharInfo(player);
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
    function setPLMMatchOrganizer(
        address _matchOrganizer
    ) external onlyPolylemmers {
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
        manager.setBattleState(msg.sender, BattleState.Settled);
        matchOrganizer.forceResetMatchState(msg.sender);
        matchOrganizer.forceResetMatchState(enemyAddr[msg.sender]);
        emit BattleCanceled(battleId[msg.sender]);
        emit ForceInited(battleId[msg.sender]);
    }
}
