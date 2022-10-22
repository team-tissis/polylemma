pragma solidity ^0.8.17;

import {IPLMSeeder} from "./interfaces/IPLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";

contract PLMSeeder is IPLMSeeder {
    function generateSeed(uint256 tokenId, IPLMData data)
        external
        view
        override
        returns (Seed memory)
    {
        uint256 pseudoRandomness = _generateRandomnessFromBlockHash(tokenId);
        uint256 numOddsCharacterType = data.numOddsCharacterType();
        uint256 numOddsAbility = data.numOddsAbility();
        uint8[] memory characterTypeOdds = data.getCharacterTypeOdds();
        uint8[] memory abilityOdds = data.getAbilityOdds();
        return
            Seed({
                characterType: characterTypeOdds[
                    pseudoRandomness % numOddsCharacterType
                ],
                ability: abilityOdds[pseudoRandomness % numOddsAbility]
            });
    }
    function generateRandomSlotNonce

    function _generateRandomnessFromBlockHash(uint256 tokenId)
        internal
        returns (uint256)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - 1), tokenId)
                )
            );
    }
}
