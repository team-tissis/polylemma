// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";

contract PLMData is IPLMData {
    // TODO: monsterblocksのmonster名で仮置きした
    // TODO: 入替可能なようにconstructorで初期化&setHogeで入替可能にするべき
    string[] public characterTypes = [
        "fire",
        "grass",
        "water",
        "dark",
        "light"
    ];

    string[] public abilities = ["mouka", "shinryoku", "gekiryu"];
    uint8[] public characterTypeOdds = [2, 2, 2, 2, 2];
    uint8[] public abilityOdds = [2, 2, 2];

    uint256[] public taxPercentageTable = [5, 10, 20, 23, 33, 40, 45];

    function getCharacterTypes()
        external
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
    }

    function countCharacterType() external view returns (uint256) {
        return characterTypes.length;
    }

    function getCharacterTypeOdds()
        external
        view
        override
        returns (uint8[] memory)
    {
        return characterTypeOdds;
    }

    function getAbilities() external view override returns (string[] memory) {
        return abilities;
    }

    function countAbilities() external view override returns (uint256) {
        return abilities.length;
    }

    function getAbilityOdds() external view override returns (uint8[] memory) {
        return abilityOdds;
    }

    // TODO: not defined yet
    function calcRarity(uint8 characterId, uint8[1] calldata abilityIds)
        external
        pure
        override
        returns (uint8)
    {
        return 0;
    }

    // This logic is derived from Pokemon
    function calcNecessaryExp(IPLMToken.CharacterInfo calldata charInfo)
        external
        pure
        returns (uint256)
    {
        return charInfo.level**3;
    }

    function numOddsCharacterType() external view returns (uint256) {
        return characterTypeOdds.length;
    }

    function numOddsAbility() external view returns (uint256) {
        return abilityOdds.length;
    }

    // TODO: 一旦ダメージはそのままレヴェルを返す
    function calcBattleResult(
        IPLMToken.CharacterInfo calldata aliceChar,
        IPLMToken.CharacterInfo calldata bobChar
    ) external pure returns (uint8, uint8) {
        return (aliceChar.level, bobChar.level);
    }

    // TODO: 一旦レベルポイントは最大値をそのまま返す。
    function calcLevelPoint(IPLMToken.CharacterInfo[4] calldata charInfos)
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

    // get a fee for converting from MATIC to coins
    function getTaxPercentage(uint256 amount) public view returns (uint256) {
        if (0 < amount && amount <= 2000 ether) {
            return taxPercentageTable[0];
        } else if (2000 ether < amount && amount <= 4000 ether) {
            return taxPercentageTable[1];
        } else if (4000 ether < amount && amount <= 5000 ether) {
            return taxPercentageTable[2];
        } else if (5000 ether < amount && amount <= 6000 ether) {
            return taxPercentageTable[3];
        } else if (6000 ether < amount && amount <= 7000 ether) {
            return taxPercentageTable[4];
        } else if (7000 ether < amount && amount <= 8000 ether) {
            return taxPercentageTable[5];
        } else {
            return taxPercentageTable[6];
        }
    }
}
