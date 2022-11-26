// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "../lib/PLMSeeder.sol";
import {IPLMAttributes} from "../interfaces/IPLMAttributes.sol";

contract PLMAttributesV1 is IPLMAttributes {
    /// @notice Number of attributes of the characters
    uint8 numAttributes = 10;

    /// @notice Number of rarity ranks of the attributes
    uint8 numAttributesRarity = 5;

    /// @notice Rarities for each attributes
    uint8[] attributeRarities = [1, 4, 3, 3, 3, 2, 2, 1, 4, 5];

    /// @notice ratio of the probability of each attribute occurrence
    uint8[] atributeOddsPerRarity = [35, 30, 20, 10, 5];

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

    // TODO: add necessary args & return vals
    // TODO; implement this function
    function _addAttributesEffect(uint8[1] memory attributeIds)
        external
        view
        returns (uint32)
    {
        // TODO: add appropriate comments & implementations
        // uint32 bigNumber = 16384;

        if (attributeIds[0] == 0) {
            // ID 0: no attributes
        } else if (attributeIds[0] == 1) {
            // ID 1: win the battle when the level is same value as the opponent
            // TODO
        } else if (attributeIds[0] == 2) {
            // ID 2: damage increase when the character is used in the first half of battle
            // TODO
        } else if (attributeIds[0] == 3) {
            // ID 3: increase winning reward
            // TODO
        } else if (attributeIds[0] == 4) {
            // ID 4: increase level points
            // TODO
        } else if (attributeIds[0] == 5) {
            // ID 5: Easy to hit a vital point
            // TODO
        } else if (attributeIds[0] == 6) {
            // ID 6: nullifies the effects of the attribute
            // TODO
        } else if (attributeIds[0] == 7) {
            // ID 7: decide the victory regardless of damage dealing
            // TODO
        } else if (attributeIds[0] == 8) {
            // ID 8: Rare characters are more likely to appear in random slots
            // TODO
        } else if (attributeIds[0] == 9) {
            // ID 9: In a match against a character stronger than you, even it the damage
            //       inflicted is small, there is a certain probability of absolute victory
            // TODO
        } else {
            revert("Unreachable !");
        }

        // TODO: implement here.
        return 0;
    }

    function getAttributeRarities() external view returns (uint8[] memory) {
        return attributeRarities;
    }

    function getNumAttributes() external view returns (uint256) {}
}
