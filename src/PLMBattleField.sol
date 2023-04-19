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
        uint256 _battleId = _battleId();
        BattleState battleState = manager.getBattleStateById(_battleId);
        require(
            _battleId == manager.getLatestBattle(_enemyAddress()) &&
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


    /// @notice Check that the random slot of the player designated by player
    ///         has already been committed, the choice of that player in this
    ///         round is randomSlot, and it has already been revealed.
    modifier readyForPlayerSeedReveal() {
        // Prevent double revealing.
        require(
            _randomSlotState(msg.sender) == RandomSlotState.Committed,
            "playerSeed has already been revealed."
        );

        address _enemyAddr = _enemyAddress();
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

        address _enemyAddr = _enemyAddress();
        PlayerState enemyState = _playerState(_enemyAddr);

        // If the enemy player has not committed yet and it's over commit time limit,
        // ban the enemy player as delayer.
        if (enemyState == PlayerState.Standby && _isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(
                _battleId(),
                manager.getNumRounds(msg.sender),
                manager.getPlayerId(_enemyAddr)
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
        uint256 _battleId = _battleId();

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
        // FIXME:
        _status[_battleId()] = _NOT_ENTERED;
    }

    /// @notice Function to execute closing round.
    /// @dev This function is automatically called in the end of _stepRound
    function _endRound(
        uint32 winnerDamage,
        uint32 loserDamage,
        address winner,
        bool isDraw
    ) internal {
        address _enemyAddr = manager.getEnemyAddress(winner);
        manager.incrementPlayerInfoWinCount(winner);
        manager.setRoundResult(
            msg.sender,
            RoundResult(isDraw, winner, _enemyAddr, winnerDamage, loserDamage)
        );
        // For local use of variables
        {
            uint8 winnerId = manager.getPlayerId(winner);
            emit RoundCompleted(
                _battleId(),
                manager.getNumRounds(msg.sender),
                isDraw,
                winnerId,
                1-winnerId,
                winnerDamage,
                loserDamage
            );
        }
    }

    /// @notice Function to execute the current round.
    /// @dev This function is automatically called after both players' choice revealment
    ///      of this round.
    function _stepRound() internal {
        // Mark the slot as used.
        _markSlot(msg.sender);
        address _enemyAddr = _enemyAddress();
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

            {
                uint8 winnerId = manager.getPlayerId(winner);
                emit BattleCompleted(
                    _battleId(),
                    numRounds - 1,
                    isDraw,
                    winnerId,
                    1-winnerId,
                    winnerCount,
                    loserCount
                );
            }
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
        dealer.refundStaminaForBattle(_enemyAddress());

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
        dealer.refundStaminaForBattle(_enemyAddress());

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
            _enemyAddress(),
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
        matchOrganizer.resetMatchStates(msg.sender, _enemyAddress());

        // settle this battle.
        manager.setBattleState(msg.sender, BattleState.Settled);
    }

    /// @notice Function to cancel this battle.
    function _cancelBattle() internal {
        matchOrganizer.resetMatchStates(msg.sender, _enemyAddress());
        manager.setBattleState(msg.sender, BattleState.Canceled);

        emit BattleCanceled(_battleId());
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
        address _enemyAddr = _enemyAddress();
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
    function _remainingLevelPoint(
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

    function _enemyAddress() internal view returns(address) {
        return manager.getEnemyAddress(msg.sender);
    }

    function _enemyId() internal view returns(uint8) {
        return manager.getPlayerId(_enemyAddress());
    }

    function _playerId() internal view returns(uint8) {
        return manager.getPlayerId(msg.sender);
    }

    function _battleId() internal view returns(uint256) {
        return manager.getLatestBattle(msg.sender);
    }


    // //////////////////////////////
    // /// BATTLE FIELD FUNCTIONS ///
    // //////////////////////////////

    function supportsInterface(
        bytes4 interfaceId
    ) external pure virtual returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPLMBattleField).interfaceId;
    }

    // ////////////////////////
    // ///      GETTERS     ///
    // ////////////////////////

    

    // ////////////////////////
    // ///      SETTERS     ///
    // ////////////////////////

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


}
