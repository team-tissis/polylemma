// SPDX-License-Idetifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {IPLMDealer} from "./IPLMDealer.sol";
import {IPLMBattleStorage} from "./IPLMBattleStorage.sol";

import {IPLMBattleField} from "./IPLMBattleField.sol";

interface IPLMBattleManager {
    function battleOfPlayerByIndex(
        address player,
        uint256 index
    ) external view returns (uint256);

    function beforeBattleStart(address home, address visitor) external;

    function getLatestBattle(address player) external view returns (uint256);

    ////////////////////////////
    /// WRITE/READ FUNCTIONS ///
    ////////////////////////////

    function setNumRounds(address player, uint8 numRound) external;

    function incrementNumRounds(address player) external;

    function setBattleState(
        address player,
        IPLMBattleField.BattleState bs
    ) external;

    function setRoundResult(
        address player,
        IPLMBattleField.RoundResult calldata rr
    ) external;

    function setBattleResult(
        address player,
        IPLMBattleField.BattleResult calldata br
    ) external;

    function setPlayerSeedCommitFromBlock(
        address player,
        uint256 playerSeedCommitFromBlock
    ) external;

    function setCommitFromBlock(
        address player,
        uint256 commitFromBlock
    ) external;

    function setRevealFromBlock(
        address player,
        uint256 revealFromBlock
    ) external;

    function setChoiceCommit(
        address player,
        IPLMBattleField.ChoiceCommit calldata choiceCommit
    ) external;

    function setChoiceCommitLevelPoint(
        address player,
        uint8 levelPoint
    ) external;

    function setChoiceCommitChoice(
        address player,
        IPLMBattleField.Choice choice
    ) external;

    function setPlayerSeedCommit(
        address player,
        IPLMBattleField.PlayerSeedCommit calldata playerSeedCommit
    ) external;

    function setPlayerSeedCommitValue(
        address player,
        bytes32 playerSeed
    ) external;

    function setPlayerInfo(
        address player,
        IPLMBattleField.PlayerInfo calldata playerInfo
    ) external;

    function incrementPlayerInfoWinCount(address player) external;

    function setPlayerInfoState(
        address player,
        IPLMBattleField.PlayerState playerState
    ) external;

    function setPlayerInfoRandomSlotState(
        address player,
        IPLMBattleField.RandomSlotState state
    ) external;

    function setPlayerInfoRandomSlotNonce(
        address player,
        bytes32 nonce
    ) external;

    function setPlayerInfoRandomSlotUsedRound(
        address player,
        uint8 usedRound
    ) external;

    function setPlayerInfoFixedSlotUsedRound(
        address player,
        uint8 slot,
        uint8 usedRound
    ) external;

    function subtractPlayerInfoRemainingLevelPoint(
        address player,
        uint8 used
    ) external;

    ////////////////////////////////
    /////   get sender's data  /////
    ////////////////////////////////
    function getNumRounds(address player) external view returns (uint8);

    function getBattleState(
        address player
    ) external view returns (IPLMBattleField.BattleState);

    function getRoundResult(
        address player,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult calldata);

    function getBattleResult(
        address player
    ) external view returns (IPLMBattleField.BattleResult calldata);

    function getPlayerSeedCommitFromBlock(
        address player
    ) external view returns (uint256);

    function getCommitFromBlock(address player) external view returns (uint256);

    function getRevealFromBlock(address player) external view returns (uint256);

    function getChoiceCommit(
        address player,
        uint8 indRound
    ) external view returns (IPLMBattleField.ChoiceCommit calldata);

    function getChoiceCommitLevelPoint(
        address player
    ) external view returns (uint8);

    function getChoiceCommitChoice(
        address player
    ) external view returns (IPLMBattleField.Choice);

    function getChoiceCommitString(
        address player
    ) external view returns (bytes32);

    function getPlayerSeedCommit(
        address player
    ) external view returns (IPLMBattleField.PlayerSeedCommit calldata);

    function getPlayerInfo(
        address player
    ) external view returns (IPLMBattleField.PlayerInfo memory);

    function getPlayerInfoAddress(
        address player
    ) external view returns (address);

    function getPlayerInfoFromBlock(
        address player
    ) external view returns (uint256);

    function getPlayerInfoFixedSlots(
        address player
    ) external view returns (uint256[4] memory);

    function getPlayerInfoFixedSlotsUsedRounds(
        address player
    ) external view returns (uint8[4] memory);

    function getPlayerInfoRandomSlot(
        address player
    ) external view returns (IPLMBattleField.RandomSlot memory);

    function getPlayerInfoRandomSlotNonce(
        address player
    ) external view returns (bytes32);

    function getPlayerInfoRandomSlotState(
        address player
    ) external view returns (IPLMBattleField.RandomSlotState);

    function getPlayerInfoRandomSlotUsedRound(
        address player
    ) external view returns (uint8);

    function getPlayerInfoRandomSlotLevel(
        address player
    ) external view returns (uint8);

    function getPlayerInfoPlayerState(
        address player
    ) external view returns (IPLMBattleField.PlayerState);

    function getPlayerInfoWinCount(
        address player
    ) external view returns (uint8);

    function getPlayerInfoMaxLevelPoint(
        address player
    ) external view returns (uint8);

    function getPlayerInfoRemainingLevelPoint(
        address player
    ) external view returns (uint8);

    ////////////////////////////////
    /////    get by battleId   /////
    ////////////////////////////////
    function getNumRoundsById(uint256 _battleId) external view returns (uint8);

    function getBattleStateById(
        uint256 _battleId
    ) external view returns (IPLMBattleField.BattleState);

    function getRoundResultById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult calldata);

    function getBattleResultById(
        uint256 _battleId
    ) external view returns (IPLMBattleField.BattleResult calldata);

    function getPlayerSeedCommitFromBlockById(
        uint256 _battleId
    ) external view returns (uint256);

    function getCommitFromBlockById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (uint256);

    function getRevealFromBlockById(
        uint256 _battleId,
        uint8 indRound
    ) external view returns (uint256);

    function getChoiceCommitById(
        uint256 _battleId,
        uint8 indRound,
        address player
    ) external view returns (IPLMBattleField.ChoiceCommit calldata);

    function getPlayerSeedCommitById(
        uint256 _battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerSeedCommit calldata);

    function getPlayerInfoById(
        uint256 _battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerInfo memory);

    function getPlayerInfoAddressById(
        uint256 _battleId,
        address player
    ) external view returns (address);

    function getPlayerInfoFromBlockById(
        uint256 _battleId,
        address player
    ) external view returns (uint256);

    function getPlayerInfoFixedSlotsById(
        uint256 _battleId,
        address player
    ) external view returns (uint256[4] memory);

    function getPlayerInfoFixedSlotsUsedRoundsById(
        uint256 _battleId,
        address player
    ) external view returns (uint8[4] memory);

    function getPlayerInfoRandomSlotById(
        uint256 _battleId,
        address player
    ) external view returns (IPLMBattleField.RandomSlot memory);

    function getPlayerInfoPlayerStateById(
        uint256 _battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerState);

    function getPlayerInfoWinCountById(
        uint256 _battleId,
        address player
    ) external view returns (uint8);

    function getPlayerInfoMaxLevelPointById(
        uint256 _battleId,
        address player
    ) external view returns (uint8);

    function getPlayerInfoRemainingLevelPointById(
        uint256 _battleId,
        address player
    ) external view returns (uint8);

    function setPLMBattleField(address _battleField) external;
}
