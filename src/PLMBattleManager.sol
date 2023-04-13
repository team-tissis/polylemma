// SPDX-License-Idetifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMBattleStorage} from "./interfaces/IPLMBattleStorage.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";

contract PLMBattleManager {
    /// @notice The number of the fixed slots that one player has.
    uint8 constant FIXED_SLOTS_NUM = 4;

    /// @notice List of IDs of battles the player has participated in. playerAddress => listIndex => battleID
    mapping(address => mapping(uint256 => uint256)) private _joinedBattles;

    /// @notice Mapping player address to Number of battles the player has participated in so far
    mapping(address => uint256) private _numBattle;

    /// @notice Mapping from battle ID to index of the joined battles list
    mapping(uint256 => uint256) private _joinedBattlesIndex;

    uint256 battleId;

    address polylemmers;
    address battleField;

    /// @notice interface to the characters' information.
    IPLMToken token;

    /// @notice interface to the database of polylemma.
    IPLMData data;

    /// @notice interface to the storage for battle information.
    IPLMBattleStorage strg;

    constructor(IPLMToken _token, IPLMBattleStorage _strg) {
        token = _token;
        strg = _strg;
        data = IPLMData(_token.getDataAddr());
        polylemmers = msg.sender;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != polylemmers");
        _;
    }

    modifier onlyBattleField() {
        require(msg.sender == battleField, "sender != battleField");
        _;
    }

    function battleOfPlayerByIndex(
        address player,
        uint256 index
    ) public view virtual returns (uint256) {
        return _joinedBattles[player][index];
    }

    function beforeBattleStart(
        address home,
        address visitor
    ) external onlyBattleField {
        battleId++;

        _addBattleToPlayerEnumeration(home, battleId);
        _addBattleToPlayerEnumeration(visitor, battleId);

        strg.writeEnemyAddress(battleId, home, visitor);
        strg.writeEnemyAddress(battleId, visitor, home);
    }

    /// @notice Obtain IDs of the most recent battles in which the player has participated
    function getLatestBattle(address player) external view returns (uint256) {
        return _latestBattle(player);
    }

    /**
     * Add new battle ID to the list of IDs of battles in which the player has participated so far
     * @param player address representing the new player of the given battle ID
     * @param battleId uint256 ID of the battle to be added to the battles list of the given address
     */
    function _addBattleToPlayerEnumeration(
        address player,
        uint256 battleId
    ) private {
        uint256 length = _numBattle[player];
        _joinedBattles[player][length] = battleId;
        _joinedBattlesIndex[battleId] = length;
    }

    function _latestBattle(address player) internal view returns (uint256) {
        return _joinedBattles[player][_numBattle[player]];
    }

    ///////////////////////
    /// internal getter ///
    ///////////////////////

    function _getPlayerAddress(uint256 _battleId, uint8 playerId) internal view returns (address) {
        return strg.loadPlayerAddressById(_battleId,playerId);
    }

    function _getNumRounds(uint256 _battleId) internal view returns (uint8) {
        try strg.loadNumRounds(_battleId) returns (uint8 numRounds) {
            return numRounds;
        } catch {
            return 0;
        }
    }

    function _getBattleState(
        uint256 _battleId
    ) internal view returns (IPLMBattleField.BattleState) {
        try strg.loadBattleState(_battleId) returns (
            IPLMBattleField.BattleState battleState
        ) {
            return battleState;
        } catch {
            return IPLMBattleField.BattleState.NotStarted;
        }
    }

    function _getRoundResult(
        uint256 _battleId,
        uint8 indRound
    ) internal view returns (IPLMBattleField.RoundResult memory) {
        return strg.loadRoundResults(_battleId, indRound);
    }

    function _getBattleResult(
        uint256 _battleId
    ) internal view returns (IPLMBattleField.BattleResult memory) {
        return strg.loadBattleResult(_battleId);
    }

    function _getPlayerSeedCommitFromBlock(
        uint256 _battleId
    ) internal view returns (uint256) {
        return strg.loadPlayerSeedCommitFromBlock(_battleId);
    }

    function _getCommitFromBlock(
        uint256 _battleId,
        uint8 indRound
    ) internal view returns (uint256) {
        return strg.loadCommitFromBlocks(_battleId, indRound);
    }

    function _getRevealFromBlock(
        uint256 _battleId,
        uint8 indRound
    ) internal view returns (uint256) {
        return strg.loadRevealFromBlocks(_battleId, indRound);
    }

    function _getChoiceCommit(
        uint256 _battleId,
        uint8 indRound,
        address player
    ) internal view returns (IPLMBattleField.ChoiceCommit memory) {
        return strg.loadChoiceCommitLog(_battleId, indRound, player);
    }

    function _getPlayerSeedCommit(
        uint256 _battleId,
        address player
    ) internal view returns (IPLMBattleField.PlayerSeedCommit memory) {
        return strg.loadPlayerSeedCommitLog(_battleId, player);
    }

    /// @notice When modifying a particular member of the structure, it is necessary to retrieve the data before the modification, so the internal function is implemented
    function _getPlayerInfo(
        uint256 _battleId,
        address player
    ) internal view returns (IPLMBattleField.PlayerInfo memory) {
        return strg.loadPlayerInfoTable(_battleId, player);
    }

    function _getEnemyAddress(
        uint256 _battleId,
        address player
    ) internal view returns (address) {
        return strg.loadEnemyAddress(_battleId, player);
    }

    ////////////////////////////
    ////    data composer   ////
    ////////////////////////////

    function _bondLevelAtBattleStart(
        uint256 _battleId,
        uint8 level,
        uint256 fromBlock,
        address player
    ) internal view returns (uint32) {
        // fromBlockは移行先に格納する必要がある．

        return
            data.getPriorBondLevel(
                level,
                fromBlock,
                _getPlayerInfo(_battleId, player).fromBlock
            );
    }

    function _totalSupplyAtFromBlock(
        uint256 _battleId,
        address player
    ) internal view returns (uint256) {
        // Here we assume that Bob is always a requester.
        return
            token.getPriorTotalSupply(
                _getPlayerInfo(_battleId, player).fromBlock
            );
    }

    ////////////////////////////
    /// WRITE/READ FUNCTIONS ///
    ////////////////////////////
    // TODO: latestbattleが更新されるよりも後に呼び出さなけれなならない
    function setPlayerAddressByPlayerId(address home, address visitor) external onlyBattleField {
        strg.writePlayerAddressByPlayerId(_latestBattle(home),home,visitor);
    } 


    function setNumRounds(
        address player,
        uint8 numRound
    ) external onlyBattleField {
        strg.writeNumRounds(_latestBattle(player), numRound);
    }

    function incrementNumRounds(address player) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        uint8 numRounds = _getNumRounds(_battleId);
        strg.writeNumRounds(_battleId, numRounds + 1);
    }

    function setBattleState(
        address player,
        IPLMBattleField.BattleState battleState
    ) external onlyBattleField {
        strg.writeBattleState(_latestBattle(player), battleState);
    }

    function setRoundResult(
        address player,
        IPLMBattleField.RoundResult calldata roundResult
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writeRoundResult(
            _latestBattle(player),
            _getNumRounds(_battleId),
            roundResult
        );
    }

    function setBattleResult(
        address player,
        IPLMBattleField.BattleResult calldata battleResult
    ) external onlyBattleField {
        strg.writeBattleResult(_latestBattle(player), battleResult);
    }

    function setPlayerSeedCommitFromBlock(
        address player,
        uint256 playerSeedCommitFromBlock
    ) external onlyBattleField {
        strg.writePlayerSeedCommitFromBlock(
            _latestBattle(player),
            playerSeedCommitFromBlock
        );
    }

    function setCommitFromBlock(
        address player,
        uint256 commitFromBlock
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writeCommitFromBlock(
            _battleId,
            _getNumRounds(_battleId),
            commitFromBlock
        );
    }

    function setRevealFromBlock(
        address player,
        uint256 revealFromBlock
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writeRevealFromBlock(
            _battleId,
            _getNumRounds(_battleId),
            revealFromBlock
        );
    }

    function setChoiceCommit(
        address player,
        IPLMBattleField.ChoiceCommit calldata choiceCommit
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writeChoiceCommitLog(
            _battleId,
            _getNumRounds(_battleId),
            player,
            choiceCommit
        );
    }

    /// @notice PUT to modify a specific member of the structure.
    function setChoiceCommitLevelPoint(
        address player,
        uint8 levelPoint
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        uint8 indRound = _getNumRounds(_battleId);
        IPLMBattleField.ChoiceCommit memory choiceCommit = _getChoiceCommit(
            _battleId,
            indRound,
            player
        );
        choiceCommit.levelPoint = levelPoint;
        strg.writeChoiceCommitLog(_battleId, indRound, player, choiceCommit);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setChoiceCommitChoice(
        address player,
        IPLMBattleField.Choice choice
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        uint8 indRound = _getNumRounds(_battleId);
        IPLMBattleField.ChoiceCommit memory choiceCommit = _getChoiceCommit(
            _battleId,
            indRound,
            player
        );
        choiceCommit.choice = choice;
        strg.writeChoiceCommitLog(_battleId, indRound, player, choiceCommit);
    }

    function setPlayerSeedCommit(
        address player,
        IPLMBattleField.PlayerSeedCommit calldata playerSeedCommit
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writePlayerSeedCommitLog(_battleId, player, playerSeedCommit);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerSeedCommitValue(
        address player,
        bytes32 playerSeed
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerSeedCommit
            memory playerSeedCommit = _getPlayerSeedCommit(_battleId, player);
        playerSeedCommit.playerSeed = playerSeed;
        strg.writePlayerSeedCommitLog(_battleId, player, playerSeedCommit);
    }

    function setPlayerInfo(
        address player,
        IPLMBattleField.PlayerInfo calldata playerInfo
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    function incrementPlayerInfoWinCount(
        address winner
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(winner);

        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            winner
        );
        playerInfo.winCount++;
        strg.writePlayerInfoTable(_battleId, winner, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerInfoState(
        address player,
        IPLMBattleField.PlayerState playerState
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.state = playerState;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerInfoRandomSlotState(
        address player,
        IPLMBattleField.RandomSlotState state
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.randomSlot.state = state;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerInfoRandomSlotNonce(
        address player,
        bytes32 nonce
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.randomSlot.nonce = nonce;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerInfoRandomSlotUsedRound(
        address player,
        uint8 usedRound
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.randomSlot.usedRound = usedRound;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function setPlayerInfoFixedSlotUsedRound(
        address player,
        uint8 slot,
        uint8 usedRound
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.fixedSlotsUsedRounds[slot] = usedRound;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    /// @notice PUT to modify a specific member of the structure.
    function subtractPlayerInfoRemainingLevelPoint(
        address player,
        uint8 used
    ) external onlyBattleField {
        uint256 _battleId = _latestBattle(player);
        IPLMBattleField.PlayerInfo memory playerInfo = _getPlayerInfo(
            _battleId,
            player
        );
        playerInfo.remainingLevelPoint -= used;
        strg.writePlayerInfoTable(_battleId, player, playerInfo);
    }

    ////////////////////////////////
    /////  get sender's data   /////
    function getPlayerId(address player) external view returns (uint8) {
        return strg.loadPlayerId(_latestBattle(player), player);
    }

    function getNumRounds(address player) external view returns (uint8) {
        return _getNumRounds(_latestBattle(player));
    }

    function getBattleState(
        address player
    ) external view returns (IPLMBattleField.BattleState) {
        return _getBattleState(_latestBattle(player));
    }

    function getRoundResult(
        address player,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult memory) {
        return _getRoundResult(_latestBattle(player), indRound);
    }

    function getBattleResult(
        address player
    ) external view returns (IPLMBattleField.BattleResult memory) {
        return _getBattleResult(_latestBattle(player));
    }

    function getPlayerSeedCommitFromBlock(
        address player
    ) external view returns (uint256) {
        return _getPlayerSeedCommitFromBlock(_latestBattle(player));
    }

    function getCommitFromBlock(
        address player
    ) external view returns (uint256) {
        uint256 _battleId = _latestBattle(player);
        return _getCommitFromBlock(_battleId, _getNumRounds(_battleId));
    }

    function getRevealFromBlock(
        address player
    ) external view returns (uint256) {
        uint256 _battleId = _latestBattle(player);
        return _getRevealFromBlock(_battleId, _getNumRounds(_battleId));
    }

    function getChoiceCommit(
        address player,
        uint8 indRound
    ) external view returns (IPLMBattleField.ChoiceCommit memory) {
        return _getChoiceCommit(_latestBattle(player), indRound, player);
    }

    function getChoiceCommitLevelPoint(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return
            _getChoiceCommit(_battleId, _getNumRounds(_battleId), player)
                .levelPoint;
    }

    function getChoiceCommitChoice(
        address player
    ) external view returns (IPLMBattleField.Choice) {
        uint256 _battleId = _latestBattle(player);
        return
            _getChoiceCommit(_battleId, _getNumRounds(_battleId), player)
                .choice;
    }

    function getChoiceCommitString(
        address player
    ) external view returns (bytes32) {
        uint256 _battleId = _latestBattle(player);
        return
            _getChoiceCommit(_battleId, _getNumRounds(_battleId), player)
                .commitString;
    }

    function getPlayerSeedCommit(
        address player
    ) external view returns (IPLMBattleField.PlayerSeedCommit memory) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerSeedCommit(_battleId, player);
    }

    function getPlayerInfo(
        address player
    ) external view returns (IPLMBattleField.PlayerInfo memory) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player);
    }

    function getPlayerInfoAddress(
        address player
    ) external view returns (address) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).addr;
    }

    function getPlayerInfoFromBlock(
        address player
    ) external view returns (uint256) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).fromBlock;
    }

    function getPlayerInfoFixedSlots(
        address player
    ) external view returns (uint256[4] memory) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).fixedSlots;
    }

    function getPlayerInfoFixedSlotsUsedRounds(
        address player
    ) external view returns (uint8[4] memory) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).fixedSlotsUsedRounds;
    }

    function getPlayerInfoRandomSlot(
        address player
    ) external view returns (IPLMBattleField.RandomSlot memory) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).randomSlot;
    }

    function getPlayerInfoRandomSlotNonce(
        address player
    ) external view returns (bytes32) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).randomSlot.nonce;
    }

    function getPlayerInfoRandomSlotState(
        address player
    ) external view returns (IPLMBattleField.RandomSlotState) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).randomSlot.state;
    }

    function getPlayerInfoRandomSlotLevel(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).randomSlot.level;
    }

    function getPlayerInfoRandomSlotUsedRound(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).randomSlot.usedRound;
    }

    function getPlayerInfoPlayerState(
        address player
    ) external view returns (IPLMBattleField.PlayerState) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).state;
    }

    function getPlayerInfoWinCount(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).winCount;
    }

    function getPlayerInfoMaxLevelPoint(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).maxLevelPoint;
    }

    function getPlayerInfoRemainingLevelPoint(
        address player
    ) external view returns (uint8) {
        uint256 _battleId = _latestBattle(player);
        return _getPlayerInfo(_battleId, player).remainingLevelPoint;
    }

    function getEnemyAddress(address player) external view returns (address) {
        return _getEnemyAddress(_latestBattle(player), player);
    }

    function getBondLevelAtBattleStart(
        address player,
        uint8 level,
        uint256 fromBlock
    ) external view returns (uint32) {
        uint256 _battleId = _latestBattle(player);
        return _bondLevelAtBattleStart(_battleId, level, fromBlock, player);
    }

    function getTotalSupplyAtFromBlock(
        address player
    ) external view returns (uint256) {
        uint256 _battleId = _latestBattle(player);
        return _totalSupplyAtFromBlock(_battleId, player);
    }

    function getVirtualRandomSlotCharInfo(
        address player,
        uint256 tokenId
    ) external view returns (IPLMToken.CharacterInfo memory) {
        uint256 _battleId = _latestBattle(player);
        IPLMToken.CharacterInfo memory virtualPlayerCharInfo = token
            .getPriorCharacterInfo(
                tokenId,
                _getPlayerInfo(_battleId, player).fromBlock
            );
        virtualPlayerCharInfo.level = _getPlayerInfo(_battleId, player)
            .randomSlot
            .level;

        return virtualPlayerCharInfo;
    }

    // FIXME:
    function getCharsUsedRounds(
        address player
    ) external view returns (uint8[5] memory) {
        uint256 _battleId = _latestBattle(player);
        uint8[5] memory order;

        // Fixed slots
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            order[slotIdx] = _getPlayerInfo(_battleId, player)
                .fixedSlotsUsedRounds[slotIdx];
        }

        // Random slots
        order[4] = _getPlayerInfo(_battleId, player).randomSlot.usedRound;

        return order;
    }

    function getRoundResults(
        address player
    ) external view returns (IPLMBattleField.RoundResult[] memory) {
        uint256 _battleId = _latestBattle(player);
        uint8 numRounds = _getNumRounds(_battleId);
        IPLMBattleField.RoundResult[]
            memory results = new IPLMBattleField.RoundResult[](numRounds);
        for (uint8 i = 0; i < numRounds; i++) {
            results[i] = _getRoundResult(_battleId, i);
        }
        return results;
    }

    ////////////////////////////////
    /////    get by battleId   /////
    ////////////////////////////////
    function getPlayerAddressById(uint256 _battleId, uint8 playerId) external view returns (address){
        return _getPlayerAddress(_battleId,playerId);
    }
    function getNumRoundsById(uint256 _battleId) external view returns (uint8) {
        return _getNumRounds(_battleId);
    }

    function getBattleStateById(
        uint256 _battleId
    ) external view returns (IPLMBattleField.BattleState) {
        return _getBattleState(_battleId);
    }

    function getRoundResultById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult memory) {
        return _getRoundResult(_battleId, indRound);
    }

    function getBattleResultById(
        uint256 _battleId
    ) external view returns (IPLMBattleField.BattleResult memory) {
        return _getBattleResult(_battleId);
    }

    function getPlayerSeedCommitFromBlockById(
        uint256 _battleId
    ) external view returns (uint256) {
        return _getPlayerSeedCommitFromBlock(_battleId);
    }

    function getCommitFromBlockById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (uint256) {
        return _getCommitFromBlock(_battleId, indRound);
    }

    function getRevealFromBlockById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (uint256) {
        return _getRevealFromBlock(_battleId, indRound);
    }

    function getChoiceCommitById(
        uint256 _battleId,
        uint8 indRound,
        uint8 playerId
    ) external view returns (IPLMBattleField.ChoiceCommit memory) {
        return _getChoiceCommit(_battleId, indRound, _getPlayerAddress(_battleId, playerId));
    }

    function getPlayerSeedCommitById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (IPLMBattleField.PlayerSeedCommit memory) {
        return _getPlayerSeedCommit(_battleId, _getPlayerAddress(_battleId, playerId));
    }

    function getBondLevelAtBattleStartById(
        uint256 _battleId,
        uint8 playerId,
        uint8 level,
        uint256 fromBlock
    ) external view returns (uint32) {
        return _bondLevelAtBattleStart(_battleId, level, fromBlock, _getPlayerAddress(_battleId, playerId));
    }
    function getTotalSupplyAtFromBlockById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint256) {
        
        return _totalSupplyAtFromBlock(_battleId, _getPlayerAddress(_battleId, playerId));
    }
    function getVirtualRandomSlotCharInfoById(
        uint256 _battleId,
        uint8 playerId,
        uint256 tokenId
    ) external view returns (IPLMToken.CharacterInfo memory) {
        address player = _getPlayerAddress(_battleId, playerId);
        IPLMToken.CharacterInfo memory virtualPlayerCharInfo = token
            .getPriorCharacterInfo(
                tokenId,
                _getPlayerInfo(_battleId, player).fromBlock
            );
        virtualPlayerCharInfo.level = _getPlayerInfo(_battleId, player)
            .randomSlot
            .level;

        return virtualPlayerCharInfo;
    }

    function getPlayerInfoById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (IPLMBattleField.PlayerInfo memory) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId));
    }

    function getPlayerInfoAddressById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (address) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).addr;
    }

    function getPlayerInfoFromBlockById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint256) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).fromBlock;
    }

    function getPlayerInfoFixedSlotsById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint256[4] memory) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).fixedSlots;
    }

    function getPlayerInfoFixedSlotsUsedRoundsById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint8[4] memory) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).fixedSlotsUsedRounds;
    }

    function getPlayerInfoRandomSlotById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (IPLMBattleField.RandomSlot memory) {
        return _getPlayerInfo(_battleId,_getPlayerAddress(_battleId, playerId)).randomSlot;
    }

    function getPlayerInfoPlayerStateById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (IPLMBattleField.PlayerState) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).state;
    }

    function getPlayerInfoWinCountById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint8) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).winCount;
    }

    function getPlayerInfoMaxLevelPointById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint8) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).maxLevelPoint;
    }

    function getPlayerInfoRemainingLevelPointById(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (uint8) {
        return _getPlayerInfo(_battleId, _getPlayerAddress(_battleId, playerId)).remainingLevelPoint;
    }

    function getEnemyAddress(
        uint256 _battleId,
        uint8 playerId
    ) external view returns (address) {
        return _getEnemyAddress(_battleId, _getPlayerAddress(_battleId, playerId));
    }

    /////////////////////////
    ////  setter for req ////
    /////////////////////////
    function setPLMBattleField(address _battleField) external onlyPolylemmers {
        battleField = _battleField;
    }
}
