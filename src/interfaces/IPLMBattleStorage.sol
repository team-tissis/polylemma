// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {SSTORE2} from "lib/sstore2/contracts/SSTORE2.sol";
import {IPLMBattleField} from "./IPLMBattleField.sol";

interface IPLMBattleStorage {
    function writePlayerAddressByPlayerId(
        uint256 battleId,
        address homeAddress,
        address visitorAddress
    ) external;

    function writeNumRounds(uint256 battleId, uint256 numRounds) external;

    function writeBattleState(
        uint256 battleId,
        IPLMBattleField.BattleState battleState
    ) external;

    function writeRoundResult(
        uint256 battleId,
        uint256 infRound,
        IPLMBattleField.RoundResult calldata roundResult
    ) external;

    function writeBattleResult(
        uint256 battleId,
        IPLMBattleField.BattleResult calldata battleResult
    ) external;

    function writePlayerSeedCommitFromBlock(
        uint256 battleId,
        uint256 playerSeedCommitFromBlock
    ) external;

    function writeCommitFromBlock(
        uint256 battleId,
        uint8 indRound,
        uint256 commitFromBlock
    ) external;

    function writeRevealFromBlock(
        uint256 battleId,
        uint8 indRound,
        uint256 revealFromBlock
    ) external;

    function writeChoiceCommitLog(
        uint256 battleId,
        uint8 indRound,
        address player,
        IPLMBattleField.ChoiceCommit calldata choiceCommit
    ) external;

    function writePlayerSeedCommitLog(
        uint256 battleId,
        address player,
        IPLMBattleField.PlayerSeedCommit calldata playerSeedCommit
    ) external;

    function writePlayerInfoTable(
        uint256 battleId,
        address player,
        IPLMBattleField.PlayerInfo calldata playerInfo
    ) external;

    function writeEnemyAddress(
        uint256 battleId,
        address player,
        address enemy
    ) external;

    function loadPlayerId(uint256 battleId, address player) external view returns(uint8);

    function loadPlayerAddressById(uint256 battleId,uint8 playerId) external view returns(address);

    function loadNumRounds(uint256 battleId) external view returns (uint8);

    function loadBattleState(
        uint256 battleId
    ) external view returns (IPLMBattleField.BattleState);

    // TODO: roundのindexを他の箇所でもindRoundと書き直す
    function loadRoundResults(
        uint256 battleId,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult memory);

    function loadBattleResult(
        uint256 battleId
    ) external view returns (IPLMBattleField.BattleResult memory);

    function loadPlayerSeedCommitFromBlock(
        uint256 battleId
    ) external view returns (uint256);

    function loadCommitFromBlocks(
        uint256 battleId,
        uint8 indRound
    ) external view returns (uint256);

    function loadRevealFromBlocks(
        uint256 battleId,
        uint8 indRound
    ) external view returns (uint256);

    function loadChoiceCommitLog(
        uint256 battleId,
        uint8 indRound,
        address player
    ) external view returns (IPLMBattleField.ChoiceCommit memory);

    function loadPlayerSeedCommitLog(
        uint256 battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerSeedCommit memory);

    function loadPlayerInfoTable(
        uint256 battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerInfo memory);

    function loadEnemyAddress(
        uint256 battleId,
        address player
    ) external view returns (address);

    ////////////////////////////
    ////   set permission   ////
    ////////////////////////////
    function setBattleManager(address _battleManager) external;
}
