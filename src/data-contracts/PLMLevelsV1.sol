// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPLMLevels} from "../interfaces/IPLMLevels.sol";
import {IPLMData} from "../interfaces/IPLMData.sol";

contract PLMLevelsV1 is IPLMLevels {
    // TODO: we should increase this factor.
    /// @notice block number needed to raise bond level by 1.
    uint256 constant UNIT_BOND_LEVEL_PERIOD = 50;

    // TODO: 一旦レベルポイントは最大値をそのまま返す。
    /// @notice Points that players can freely distribute just before the start of battle.
    /// @dev levelPoints is the maximum level in the party.
    function _calcLevelPoint(
        IPLMData.CharacterInfoMinimal[4] calldata charInfos
    ) internal pure returns (uint8) {
        uint8 maxLevel = 0;
        for (uint8 slotIdx = 0; slotIdx < 4; slotIdx++) {
            if (charInfos[slotIdx].level > maxLevel) {
                maxLevel = charInfos[slotIdx].level;
            }
        }
        return maxLevel;
    }

    // TODO: 一旦ランダムスロットのレベルは固定スロットの平均値を返す。
    /// @notice Determine the level of random slots from the level of fixed slots
    function _calcRandomSlotLevel(
        IPLMData.CharacterInfoMinimal[4] calldata charInfos
    ) internal pure returns (uint8) {
        uint16 sumLevel = 0;
        for (uint8 slotIdx = 0; slotIdx < 4; slotIdx++) {
            sumLevel += uint16(charInfos[slotIdx].level);
        }
        return uint8(sumLevel / 4);
    }

    function _calcBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) internal pure returns (uint32) {
        uint32 ownershipPeriod = uint32(
            (toBlock - fromBlock) / UNIT_BOND_LEVEL_PERIOD
        );
        return ownershipPeriod < level * 2 ? ownershipPeriod : level * 2;
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    /// @notice Function to calculate current bond level.
    function getCurrentBondLevel(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32)
    {
        return _calcBondLevel(level, fromBlock, block.number);
    }

    /// @notice Function to calculate prior bond level.
    function getPriorBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (uint32) {
        return _calcBondLevel(level, fromBlock, toBlock);
    }

    /// @notice get points that players can freely distribute just before the start of battle.
    /// @dev levelPoints is the maximum level in the party.
    function getLevelPoint(IPLMData.CharacterInfoMinimal[4] calldata charInfos)
        external
        pure
        returns (uint8)
    {
        return _calcLevelPoint(charInfos);
    }

    /// @notice get the level of random slots from the level of fixed slots
    function getRandomSlotLevel(
        IPLMData.CharacterInfoMinimal[4] calldata charInfos
    ) external pure returns (uint8) {
        return _calcRandomSlotLevel(charInfos);
    }
}
