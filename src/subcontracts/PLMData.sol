// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "../lib/PLMSeeder.sol";
import {IPLMData} from "../interfaces/IPLMData.sol";

contract PLMData is IPLMData {
    // TODO: 入替可能なようにconstructorで初期化&setHogeで入替可能にするべき
    string[] public characterTypes = ["Fire", "Grass", "Water"];

    /// @notice ratio of probability of type occurrence
    uint8[] public characterTypeOdds = [1, 1, 1];

    /// @notice rarity of attribute
    uint8[] public attributeRarities = [1, 4, 3, 3, 3, 2, 2, 1, 4, 5];

    /// @notice ratio of probability of attribute occurrence
    uint8[] public attributeOddsPerRarity = [35, 30, 20, 10, 5];

    /// @notice number of PLMToken images
    uint256 numImg = 38;

    /// @notice Progressive taxation of coin issuance through billing
    uint256[] public poolingPercentageTable = [5, 10, 20, 23, 33, 40, 45];

    function _mulFloat(
        uint256 x,
        uint256 denominator,
        uint256 numerator
    ) internal pure returns (uint32) {
        return uint32((x * denominator) / numerator);
    }

    function _rate(uint8 x) internal view returns (bool) {
        return uint256(PLMSeeder.randomFromBlockHash()) % 100 < x;
    }

    function _characterTypes() internal view returns (string[] memory) {
        return characterTypes;
    }

    function _typeCompatibility(
        string calldata playerType,
        string calldata enemyType
    ) internal pure returns (uint8, uint8) {
        bytes32 playerTypeBytes = keccak256(abi.encodePacked(playerType));
        bytes32 enemyTypeBytes = keccak256(abi.encodePacked(enemyType));
        bytes32 fire = keccak256(abi.encodePacked("fire"));
        bytes32 grass = keccak256(abi.encodePacked("grass"));
        bytes32 water = keccak256(abi.encodePacked("water"));
        if (playerTypeBytes == enemyTypeBytes) {
            return (1, 1);
        } else if (
            (playerTypeBytes == fire && enemyTypeBytes == grass) ||
            (playerTypeBytes == grass && enemyTypeBytes == water) ||
            (playerTypeBytes == water && enemyTypeBytes == fire)
        ) {
            return (12, 10);
        } else if (
            (enemyTypeBytes == fire && playerTypeBytes == grass) ||
            (enemyTypeBytes == grass && playerTypeBytes == water) ||
            (enemyTypeBytes == water && playerTypeBytes == fire)
        ) {
            return (8, 10);
        } else {
            // TODO: Error handling
            return (1, 1);
        }
    }

    function _calcRarity(uint8[1] memory attributeIds)
        internal
        view
        returns (uint8)
    {
        return attributeRarities[attributeIds[0]];
    }

    /// @dev This logic is derived from Pokemon
    function _calcNecessaryExp(CharacterInfo memory charInfo)
        internal
        pure
        returns (uint256)
    {
        return uint256(charInfo.level)**2;
    }

    /// @notice function to simulate the battle and return back result to BattleField contract.
    function _calcDamage(
        uint8 numRounds,
        CharacterInfo calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfo calldata enemyChar
    ) internal view returns (uint32) {
        uint32 bigNumber = 16384;
        uint8 baseDamageRate = 10;

        uint256 denominator;
        uint256 numerator;
        (denominator, numerator) = _typeCompatibility(
            playerChar.characterType,
            enemyChar.characterType
        );

        uint32 damage = playerChar.level * baseDamageRate;
        if (_rate(30)) {
            damage += playerBondLevel;
        }

        if (playerChar.attributeIds[0] == 0) {
            // ID 0: no attributes
            damage += playerLevelPoint * baseDamageRate;
            damage = _mulFloat(damage, denominator, numerator);
        } else if (playerChar.attributeIds[0] == 1) {
            // ID 1: win the battle when the level is same value as the opponent
            damage += playerLevelPoint * baseDamageRate;
            if (playerChar.level == enemyChar.level) {
                denominator *= bigNumber;
            }
            damage = _mulFloat(damage, denominator, numerator);
        } else if (playerChar.attributeIds[0] == 2) {
            // ID 2: damage increase when the character is used in the first half of battle
            damage += playerLevelPoint * baseDamageRate;
            if (_rate(30)) {
                denominator *= 15 - numRounds;
                numerator *= 10;
            }
            damage = _mulFloat(damage, denominator, numerator);
        } else if (playerChar.attributeIds[0] == 3) {
            // ID 3: increase winning reward
            damage += playerLevelPoint * baseDamageRate;
            damage = _mulFloat(damage, denominator, numerator);
            // TODO: 得られるコインを増やす
        } else if (playerChar.attributeIds[0] == 4) {
            // ID 4: increase level points
            damage = _mulFloat(damage, denominator, numerator);
            damage += _mulFloat(
                playerLevelPoint * baseDamageRate,
                15 * denominator,
                10 * numerator
            );
        } else if (playerChar.attributeIds[0] == 5) {
            // ID 5: Easy to hit a vital point
            damage += playerLevelPoint * baseDamageRate;
            if (_rate(20)) {
                denominator *= 12;
                numerator *= 10;
            }
            damage = _mulFloat(damage, denominator, numerator);
        } else if (playerChar.attributeIds[0] == 6) {
            // ID 6: nullifies the effects of the attribute
            damage += playerLevelPoint * baseDamageRate;
        } else if (playerChar.attributeIds[0] == 7) {
            // ID 7: decide the victory regardless of damage dealing
            damage += playerLevelPoint * baseDamageRate;
            if (_rate(5)) {
                denominator *= bigNumber;
            }
            damage = _mulFloat(damage, denominator, numerator);
        } else if (playerChar.attributeIds[0] == 8) {
            // ID 8: Rare characters are more likely to appear in random slots
            damage += playerLevelPoint * baseDamageRate;
            damage = _mulFloat(damage, denominator, numerator);
            // TODO: RS でレア度が高いキャラが出やすいようにする
        } else if (playerChar.attributeIds[0] == 9) {
            // ID 9: In a match against a character stronger than you, even if the damage inflicted is small, there is a certain probability of absolute victory
            damage += playerLevelPoint * baseDamageRate;
            if (enemyChar.level > playerChar.level) {
                uint8 levelDiff = enemyChar.level - playerChar.level;
                if (levelDiff <= 10 && _rate(levelDiff * 10)) {
                    denominator *= bigNumber;
                }
            }
            damage = _mulFloat(damage, denominator, numerator);
        } else {
            // TODO: Error handling
            damage += playerLevelPoint * baseDamageRate;
            damage = _mulFloat(damage, denominator, numerator);
        }
        return damage;
    }

    // TODO: 一旦レベルポイントは最大値をそのまま返す。
    /// @notice Points that players can freely distribute just before the start of battle.
    /// @dev levelPoints is the maximum level in the party.
    function _calcLevelPoint(CharacterInfo[4] calldata charInfos)
        internal
        pure
        returns (uint8)
    {
        uint8 maxLevel = 0;
        for (uint8 i = 0; i < 4; i++) {
            if (charInfos[i].level > maxLevel) {
                maxLevel = charInfos[i].level;
            }
        }
        return maxLevel;
    }

    // TODO: 一旦ランダムスロットのレベルは固定スロットの平均値を返す。
    /// @notice Determine the level of random slots from the level of fixed slots
    function _calcRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        internal
        pure
        returns (uint8)
    {
        uint16 sumLevel = 0;
        for (uint256 i = 0; i < 4; i++) {
            sumLevel += uint16(charInfos[i].level);
        }
        return uint8(sumLevel / 4);
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    /// @notice function to simulate the battle and return back result to BattleField contract.
    function getDamage(
        uint8 numRounds,
        CharacterInfo calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfo calldata enemyChar
    ) external view returns (uint32) {
        return
            _calcDamage(
                numRounds,
                playerChar,
                playerLevelPoint,
                playerBondLevel,
                enemyChar
            );
    }

    /// @notice get points that players can freely distribute just before the start of battle.
    /// @dev levelPoints is the maximum level in the party.
    function getLevelPoint(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8)
    {
        return _calcLevelPoint(charInfos);
    }

    /// @notice get the level of random slots from the level of fixed slots
    function getRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8)
    {
        return _calcRandomSlotLevel(charInfos);
    }

    /// @notice get the percentage of pooling of PLMCoins minted when player charged MATIC.
    function getPoolingPercentage(uint256 amount)
        external
        view
        returns (uint256)
    {
        if (0 < amount && amount <= 80 ether) {
            return poolingPercentageTable[0];
        } else if (80 ether < amount && amount <= 160 ether) {
            return poolingPercentageTable[1];
        } else if (160 ether < amount && amount <= 200 ether) {
            return poolingPercentageTable[2];
        } else if (200 ether < amount && amount <= 240 ether) {
            return poolingPercentageTable[3];
        } else if (240 ether < amount && amount <= 280 ether) {
            return poolingPercentageTable[4];
        } else if (280 ether < amount && amount <= 320 ether) {
            return poolingPercentageTable[5];
        } else {
            return poolingPercentageTable[6];
        }
    }

    function getCharacterTypes()
        external
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
    }

    function getNumCharacterTypes() external view returns (uint256) {
        return characterTypes.length;
    }

    function getCumulativeCharacterTypeOdds()
        external
        view
        override
        returns (uint8[] memory)
    {
        uint256 numCharacterTypes = characterTypes.length;
        uint8[] memory cumulativeCharacterTypeOdds = new uint8[](
            numCharacterTypes
        );
        cumulativeCharacterTypeOdds[0] = characterTypeOdds[0];
        for (uint256 i = 1; i < numCharacterTypes; i++) {
            cumulativeCharacterTypeOdds[i] =
                cumulativeCharacterTypeOdds[i - 1] +
                characterTypeOdds[i];
        }
        return cumulativeCharacterTypeOdds;
    }

    function getAttributeRarities()
        external
        view
        override
        returns (uint8[] memory)
    {
        return attributeRarities;
    }

    function getNumAttributes() external view override returns (uint256) {
        return attributeRarities.length;
    }

    function getCumulativeAttributeOdds()
        external
        view
        override
        returns (uint8[] memory)
    {
        uint256 numRarities = attributeOddsPerRarity.length;
        uint256[] memory numPerRarity = new uint256[](numRarities);
        for (uint256 i = 0; i < numRarities; i++) {
            numPerRarity[i] = 0;
        }

        uint256 numAttributes = attributeRarities.length;
        for (uint256 i = 0; i < numAttributes; i++) {
            numPerRarity[attributeRarities[i] - 1]++;
        }

        uint8[] memory cumulativeAttributeOdds = new uint8[](numAttributes);
        cumulativeAttributeOdds[0] =
            uint8(
                attributeOddsPerRarity[attributeRarities[0] - 1] /
                    numPerRarity[attributeRarities[0] - 1]
            ) +
            1;
        for (uint256 i = 1; i < numAttributes; i++) {
            cumulativeAttributeOdds[i] =
                cumulativeAttributeOdds[i - 1] +
                uint8(
                    attributeOddsPerRarity[attributeRarities[i] - 1] /
                        numPerRarity[attributeRarities[i] - 1]
                ) +
                1;
        }

        return cumulativeAttributeOdds;
    }

    function getNumImg() external view returns (uint256) {
        return numImg;
    }
}
