// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "../lib/PLMSeeder.sol";
import {IPLMData} from "../interfaces/IPLMData.sol";

contract PLMData is IPLMData {
    // TODO: monsterblocksのmonster名で仮置きした
    // TODO: 入替可能なようにconstructorで初期化&setHogeで入替可能にするべき
    string[] public characterTypes = [
        "fire",
        "grass",
        "water"
        // "dark",
        // "light"
    ];

    uint8[] public characterTypeOdds = [1, 1, 1];
    uint8[] public attributeRarities = [1, 4, 3, 3, 3, 2, 2, 1, 4, 5];
    uint8[] public attributeOddsPerRarity = [35, 30, 20, 10, 5];

    uint256 numImg = 38;
    uint256[] public poolingPercentageTable = [5, 10, 20, 23, 33, 40, 45];

    function getCharacterTypes()
        public
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
    }

    function countCharacterTypes() external view returns (uint256) {
        return characterTypes.length;
    }

    function getCumulativeCharacterTypeOdds()
        external
        view
        override
        returns (uint8[] memory)
    {
        require(
            characterTypes.length == characterTypeOdds.length,
            "characterTypes.length != characterTypeOdds.length"
        );

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

    function countAttributes() external view override returns (uint256) {
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

    function _mulFloat(
        uint256 x,
        uint256 denominator,
        uint256 numerator
    ) internal pure returns (uint32) {
        return uint32((x * denominator) / numerator);
    }

    function _rate(uint8 x) internal view returns (bool) {
        return uint256(PLMSeeder.generateRandomSlotNonce()) % 100 < x;
    }

    function _typeCompatibility(
        string calldata player1Type,
        string calldata player2Type
    ) internal pure returns (uint8, uint8) {
        bytes32 player1TypeBytes = keccak256(abi.encodePacked(player1Type));
        bytes32 player2TypeBytes = keccak256(abi.encodePacked(player2Type));
        bytes32 fire = keccak256(abi.encodePacked("fire"));
        bytes32 grass = keccak256(abi.encodePacked("grass"));
        bytes32 water = keccak256(abi.encodePacked("water"));
        if (player1TypeBytes == player2TypeBytes) {
            return (1, 1);
        } else if (
            (player1TypeBytes == fire && player2TypeBytes == grass) ||
            (player1TypeBytes == grass && player2TypeBytes == water) ||
            (player1TypeBytes == water && player2TypeBytes == fire)
        ) {
            return (12, 10);
        } else if (
            (player2TypeBytes == fire && player1TypeBytes == grass) ||
            (player2TypeBytes == grass && player1TypeBytes == water) ||
            (player2TypeBytes == water && player1TypeBytes == fire)
        ) {
            return (8, 10);
        } else {
            // TODO: Error handling
            return (1, 1);
        }
    }

    /// @notice function to simulate the battle and return back result to BattleField contract.
    function calcPower(
        uint8 numRounds,
        CharacterInfo calldata player1Char,
        uint8 player1LevelPoint,
        uint32 player1BondLevel,
        CharacterInfo calldata player2Char
    ) external view returns (uint32) {
        uint32 bigNumber = 16384;
        uint8 basePowerRate = 10;

        uint256 denominator;
        uint256 numerator;
        (denominator, numerator) = _typeCompatibility(
            player1Char.characterType,
            player2Char.characterType
        );

        uint32 power = player1Char.level * basePowerRate;
        if (_rate(30)) {
            power += player1BondLevel;
        }

        if (player1Char.attributeIds[0] == 0) {
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 1) {
            power += player1LevelPoint * basePowerRate;
            if (player1Char.level == player2Char.level) {
                denominator += bigNumber;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 2) {
            power += player1LevelPoint * basePowerRate;
            if (_rate(30)) {
                denominator *= 15 - numRounds;
                numerator *= 10;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 3) {
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
            // TODO: 得られるコインを増やす
        } else if (player1Char.attributeIds[0] == 4) {
            power = _mulFloat(power, denominator, numerator);
            power += _mulFloat(
                player1LevelPoint * basePowerRate,
                15 * denominator,
                10 * numerator
            );
        } else if (player1Char.attributeIds[0] == 5) {
            power += player1LevelPoint * basePowerRate;
            if (_rate(20)) {
                denominator *= 12;
                numerator *= 10;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 6) {
            power += player1LevelPoint * basePowerRate;
        } else if (player1Char.attributeIds[0] == 7) {
            power += player1LevelPoint * basePowerRate;
            if (_rate(5)) {
                denominator *= bigNumber;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 8) {
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
            // TODO: RS でレア度が高いキャラが出やすいようにする
        } else if (player1Char.attributeIds[0] == 9) {
            power += player1LevelPoint * basePowerRate;
            if (player2Char.level > player1Char.level) {
                uint8 levelDiff = player2Char.level - player1Char.level;
                if (levelDiff <= 10 && _rate(levelDiff * 10)) {
                    denominator *= bigNumber;
                }
            }
            power = _mulFloat(power, denominator, numerator);
        } else {
            // TODO: Error handling
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
        }
        return power;
    }

    // TODO: 一旦レベルポイントは最大値をそのまま返す。
    function calcLevelPoint(CharacterInfo[4] calldata charInfos)
        external
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
    function calcRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8)
    {
        uint16 sumLevel = 0;
        for (uint256 i = 0; i < 4; i++) {
            sumLevel += uint16(charInfos[i].level);
        }
        return uint8(sumLevel / 4);
    }

    // get the percentage of pooling of PLMCoins minted when player charged MATIC.
    function getPoolingPercentage(uint256 amount)
        public
        view
        returns (uint256)
    {
        if (0 < amount && amount <= 2000 ether) {
            return poolingPercentageTable[0];
        } else if (2000 ether < amount && amount <= 4000 ether) {
            return poolingPercentageTable[1];
        } else if (4000 ether < amount && amount <= 5000 ether) {
            return poolingPercentageTable[2];
        } else if (5000 ether < amount && amount <= 6000 ether) {
            return poolingPercentageTable[3];
        } else if (6000 ether < amount && amount <= 7000 ether) {
            return poolingPercentageTable[4];
        } else if (7000 ether < amount && amount <= 8000 ether) {
            return poolingPercentageTable[5];
        } else {
            return poolingPercentageTable[6];
        }
    }

    // TODO: not defined yet
    function _calcRarity(uint8 characterId, uint8[1] memory attributeIds)
        internal
        view
        returns (uint8)
    {
        return attributeRarities[attributeIds[0]];
    }

    // This logic is derived from Pokemon
    function _calcNecessaryExp(CharacterInfo memory charInfo)
        internal
        pure
        returns (uint256)
    {
        return uint256(charInfo.level)**2;
    }
}
