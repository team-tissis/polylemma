// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPLMTypes} from "../interfaces/IPLMTypes.sol";

// This contract is used to manage characters' types information.
contract PLMTypesV1 is IPLMTypes {
    /// @notice num of types
    uint8 numTypes = 3;

    /// @notice address of the account who can add new types.
    address polylemmers;

    /// @notice name of each types
    string[] characterTypeNames = ["Fire", "Grass", "Water"];

    /// @notice ratio of probability of type occurrence
    uint8[] characterTypeOdds = [1, 1, 1];

    constructor() {
        polylemmers = msg.sender;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != deployer");
        _;
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    /// @notice function to calculate the type compatibility.
    /// @dev TODO: make this function upgradeable.
    function getTypeCompatibility(
        uint8 playerTypeId,
        uint8 enemyTypeId
    ) external view returns (uint8, uint8) {
        if (playerTypeId == enemyTypeId) {
            // In case that both character have the same types.
            return (1, 1);
        } else if ((playerTypeId + 1) % numTypes == enemyTypeId) {
            // The type of id i is super effective to the type of id i+1.
            return (12, 10);
        } else if (playerTypeId == (enemyTypeId + 1) % numTypes) {
            // The type of id i is not effective to the type of id i-1.
            return (8, 10);
        } else {
            // The type of id i is normal to the type of non-adjacent id.
            return (1, 1);
        }
    }

    function getTypeName(uint8 typeId) external view returns (string memory) {
        require(typeId < numTypes, "index out of range");
        return characterTypeNames[typeId];
    }

    function getNumCharacterTypes() external view returns (uint8) {
        return numTypes;
    }

    function getCharacterTypeOdds() external view returns (uint8[] memory) {
        return characterTypeOdds;
    }

    function getCharacterTypes() external view returns (string[] memory) {
        return characterTypeNames;
    }

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    /// @notice Function to set new types with name and odds.
    function setNewType(
        string calldata name,
        uint8 odds
    ) external onlyPolylemmers {
        numTypes++;
        characterTypeNames.push(name);
        characterTypeOdds.push(odds);
        emit NewTypeAdded(numTypes - 1, name, odds);
    }
}
