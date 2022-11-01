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
        "water",
        // "dark",
        // "light"
    ];
    uint8[] public characterTypeOdds = [2, 2, 2];

    uint8[] public characterTypeOdds = [0, 1, 2];
    uint256 numImg = 38;
    string[] public attributes = [0, 1, 2, 3, 4, 5, 6, 7];
    uint8[] public attributeRarities = [1, 4, 3, 3, 3, 2, 2, 1];

    uint256[] public poolingPercentageTable = [5, 10, 20, 23, 33, 40, 45];

    function getCharacterTypes()
        public
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
    }

    function countCharacterType() external view returns (uint256) {
        return characterTypes.length;
    }

    function getAttributes() external view override returns (string[] memory) {
        return attributes;
    }

    function countAttributes() external view override returns (uint256) {
        return attributes.length;
    }

    function getCharacterTypeOdds()
        external
        view
        override
        returns (uint8[] memory)
    {
        return characterTypeOdds;
    }

    function getNumOddsCharacterType() external view returns (uint256) {
        return characterTypeOdds.length;
    }

    function getAttributeOdds() external view override returns (uint8[] memory) {
        return attributeOdds;
    }

    function numOddsAttribute() external view returns (uint256) {
        return attributeOdds.length;
    }


    function _mulFloat(uint32 x, uint256 denominator, uint256 numerator) internal pure returns (uint32) {
        return (x * denominator) / numerator;
    }

    function _rate(uint8 x) internal view returns (bool) {
        return PLMSeeder.generateRandomSlotNonce() % 100 < y;
    }

    function _typeCompatibility(string player1Type, string player2Type) internal pure returns (uint8, uint8) {
        if (player1Type == player2Type) {
            return (1, 1);
        } else if ((player1Type == "fire" && player2Type == "grass")
                || (player1Type == "grass" && player2Type == "water")
                || (player1Type == "water" && player2Type == "fire")) {
            return (12, 10);
        } else if ((player2Type == "fire" && player1Type == "grass")
                || (player2Type == "grass" && player1Type == "water")
                || (player2Type == "water" && player1Type == "fire")) {
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
        CharacterInfo calldata player2Char
    ) external view returns (uint32) {
        uint32 bigNumber = 4096;
        uint8 basePowerRate = 10;
        uint256 blockPeriod = 10; // TODO: 大きくする
        uint256 ownershipPeriod = _mulFloat((block.number - player1Char.fromBlock), basePowerRate, blockPeriod);

        uint256 denominator;
        uint256 numerator;
        (denominator, numerator) = _typeCompatibility(player1Char.characterType, player2Char.characterType);

        uint32 power = player1Char.level * basePowerRate;
        if (player1Char.attributeIds[0] == 0) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 1) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            if (player1Char.level == player2Char.level) {
                denominator += bigNumber;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 2) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            if (_rate(30)) {
                denominator *= 15 - numRounds;
                numerator *= 10;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 3) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            power = _mulFloat(power, denominator, numerator);
            // TODO: 得られるコインを増やす
        } else if (player1Char.attributeIds[0] == 4) {
            power += ownershipPeriod;
            power = _mulFloat(power, denominator, numerator);
            power += _mulFloat(player1LevelPoint * basePowerRate, 15 * denominator, 10 * numerator);
        } else if (player1Char.attributeIds[0] == 5) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            if (_rate(20)) {
                denominator *= 12;
                numerator *= 10;
            }
            power = _mulFloat(power, denominator, numerator);
        } else if (player1Char.attributeIds[0] == 6) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
        } else if (player1Char.attributeIds[0] == 7) {
            power += ownershipPeriod;
            power += player1LevelPoint * basePowerRate;
            if (_rate(5)) {
                denominator *= bigNumber;
            }
            power = _mulFloat(power, denominator, numerator);
        } else {
            // TODO: Error handling
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
        pure
        returns (uint8)
    {
        return 0;
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
