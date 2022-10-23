// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMData} from "./interfaces/IPLMData.sol";

abstract contract PLMData is IPLMData {
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

    function getCharacterTypes()
        external
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
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

    function getAbilityOdds() external view override returns (uint8[] memory) {
        return abilityOdds;
    }

    // TODO: not defined yet
    function calcRarity(uint8 characterId, uint8[1] calldata abilityIds)
        external
        view
        override
        returns (uint8)
    {
        return 0;
    }

    function numOddsCharacterType() external view returns (uint256) {
        return characterTypeOdds.length;
    }

    function numOddsAbility() external view returns (uint256) {
        return abilityOdds.length;
    }
}