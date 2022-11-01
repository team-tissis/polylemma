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

    // TODO: 一旦ダメージはそのままレヴェルを返す
    /// @notice function to simulate the battle and return back result to BattleField contract.
    function calcBattleResult(
        uint8 numRounds,
        CharacterInfo calldata aliceChar,
        CharacterInfo calldata bobChar,
        uint8 aliceLevelPoint,
        uint8 bobLevelPoint
    ) external pure returns (uint8, uint8) {
        uint32 bigNumber = 4096;
        uint8 basePowerRate = 10;

        uint32[2] memory powers;
        powers[0] = aliceChar.level * basePowerRate;
        powers[1] = bobChar.level * basePowerRate;

        CharacterInfo[2] memory chars;
        chars[0] = aliceChar;
        chars[1] = bobChar;

        uint256 blockPeriod = 10; // TODO: 大きくする
        uint256[2] memory ownershipPeriod;
        ownershipPeriod[0] = _mulFloat((block.number - alice.fromBlock), basePowerRate, blockPeriod);
        ownershipPeriod[1] = _mulFloat((block.number - bob.fromBlock), basePowerRate, blockPeriod);

        uint8[2] memory levelPoints;
        levelPoints[0] = aliceLevelPoint;
        levelPoints[1] = bobLevelPoint;

        for (uint8 i = 0; i < 2; i++) {
            uint256 denominator;
            uint256 numerator;
            (denominator, numerator) = _typeCompatibility(chars[i].characterType, chars[1-i].characterType);
            if (Chars[i].attributeIds[0] == 0) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                powers[i] = _mulFloat(powers[i], denominator, numerator);
            } else if (Chars[i].attributeIds[0] == 1) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                if (chars[0].level == chars[1].level) {
                    denominator += bigNumber;
                }
                powers[i] = _mulFloat(powers[i], denominator, numerator);
            } else if (Chars[i].attributeIds[0] == 2) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                if (_rate(30)) {
                    denominator *= 15 - numRounds;
                    numerator *= 10;
                }
                powers[i] = _mulFloat(powers[i], denominator, numerator);
            } else if (Chars[i].attributeIds[0] == 3) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                powers[i] = _mulFloat(powers[i], denominator, numerator);
                // TODO: 得られるコインを増やす
            } else if (Chars[i].attributeIds[0] == 4) {
                powers[i] += ownershipPeriod[i];
                powers[i] = _mulFloat(powers[i], denominator, numerator);
                powers[i] += _mulFloat(levelPoints[i] * basePowerRate, 15 * denominator, 10 * numerator);
            } else if (Chars[i].attributeIds[0] == 5) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                if (_rate(20)) {
                    denominator *= 12;
                    numerator *= 10;
                }
                powers[i] = _mulFloat(powers[i], denominator, numerator);
            } else if (Chars[i].attributeIds[0] == 6) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
            } else if (Chars[i].attributeIds[0] == 7) {
                powers[i] += ownershipPeriod[i];
                powers[i] += levelPoints[i] * basePowerRate;
                if (_rate(5)) {
                    denominator *= bigNumber;
                }
                powers[i] = _mulFloat(powers[i], denominator, numerator);
            } else {
                // TODO: Error handling
            }
        }
        return (powers[0], powers[1]);
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
