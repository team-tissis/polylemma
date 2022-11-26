// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMSeeder} from "./lib/PLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMTypes} from "./interfaces/IPLMTypes.sol";
import {IPLMLevels} from "./interfaces/IPLMLevels.sol";

contract PLMData is IPLMData {
    /// @notice interface to character type database.
    IPLMTypes types;

    /// @notice interface to level database.
    IPLMLevels levels;

    /// @notice address of the account who has the right to change databases.
    address polylemmers;

    /// @notice rarity of attribute
    uint8[] attributeRarities = [1, 4, 3, 3, 3, 2, 2, 1, 4, 5];

    /// @notice ratio of probability of attribute occurrence
    uint8[] attributeOddsPerRarity = [35, 30, 20, 10, 5];

    constructor(IPLMTypes _types, IPLMLevels _levels) {
        types = _types;
        levels = _levels;
        polylemmers = msg.sender;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != polylemmers");
        _;
    }

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

    /// @notice function to simulate the battle and return back result to BattleField contract.
    function _calcDamage(
        uint8 numRounds,
        CharacterInfoMinimal calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfoMinimal calldata enemyChar
    ) internal view returns (uint32) {
        uint32 bigNumber = 16384;
        uint8 baseDamageRate = 10;

        uint256 denominator;
        uint256 numerator;
        (denominator, numerator) = types.getTypeCompatibility(
            playerChar.characterTypeId,
            enemyChar.characterTypeId
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

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    /// @notice Function to calculate current bond level.
    function getCurrentBondLevel(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32)
    {
        return levels.getCurrentBondLevel(level, fromBlock);
    }

    /// @notice Function to calculate prior bond level.
    function getPriorBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (uint32) {
        return levels.getPriorBondLevel(level, fromBlock, toBlock);
    }

    /// @notice function to simulate the battle and return back result to BattleField contract.
    function getDamage(
        uint8 numRounds,
        CharacterInfoMinimal calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfoMinimal calldata enemyChar
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
    function getLevelPoint(CharacterInfoMinimal[4] calldata charInfos)
        external
        view
        returns (uint8)
    {
        return levels.getLevelPoint(charInfos);
    }

    /// @notice get the level of random slots from the level of fixed slots
    function getRandomSlotLevel(CharacterInfoMinimal[4] calldata charInfos)
        external
        view
        returns (uint8)
    {
        return levels.getRandomSlotLevel(charInfos);
    }

    function getCharacterTypes() external view returns (string[] memory) {
        return types.getCharacterTypes();
    }

    function getNumCharacterTypes() external view returns (uint256) {
        return types.getNumCharacterTypes();
    }

    function getCumulativeCharacterTypeOdds()
        external
        view
        returns (uint8[] memory)
    {
        uint256 numCharacterTypes = types.getNumCharacterTypes();
        uint8[] memory cumulativeCharacterTypeOdds = new uint8[](
            numCharacterTypes
        );
        uint8[] memory characterTypeOdds = types.getCharacterTypeOdds();
        cumulativeCharacterTypeOdds[0] = characterTypeOdds[0];
        for (uint256 i = 1; i < numCharacterTypes; i++) {
            cumulativeCharacterTypeOdds[i] =
                cumulativeCharacterTypeOdds[i - 1] +
                characterTypeOdds[i];
        }
        return cumulativeCharacterTypeOdds;
    }

    function getAttributeRarities() external view returns (uint8[] memory) {
        return attributeRarities;
    }

    function getNumAttributes() external view returns (uint256) {
        return attributeRarities.length;
    }

    function getCumulativeAttributeOdds()
        external
        view
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

    /// @dev This logic is derived from Pokemon
    function getNecessaryExp(CharacterInfoMinimal memory charInfo)
        external
        pure
        returns (uint256)
    {
        return uint256(charInfo.level)**2;
    }

    /// @notice Function to get the rarity of the attributes designated by attributesIds.
    function getRarity(uint8[1] memory attributeIds)
        external
        view
        returns (uint8)
    {
        return attributeRarities[attributeIds[0]];
    }

    /// @notice Function to get the name of the type of typeId.
    function getTypeName(uint8 typeId) external view returns (string memory) {
        return types.getTypeName(typeId);
    }

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    function setNewTypes(IPLMTypes newTypes) external onlyPolylemmers {
        address oldTypesAddr = address(types);
        types = newTypes;
        emit TypesDatabaseUpdated(oldTypesAddr, address(newTypes));
    }

    function setNewLevels(IPLMLevels newLevels) external onlyPolylemmers {
        address oldLevelsAddr = address(levels);
        levels = newLevels;
        emit LevelsDatabaseUpdated(oldLevelsAddr, address(newLevels));
    }
}
