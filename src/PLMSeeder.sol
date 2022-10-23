pragma solidity ^0.8.17;

import {IPLMSeeder} from "./interfaces/IPLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";

contract PLMSeeder is IPLMSeeder {
    IPLMData data;
    IPLMToken token;

    constructor(IPLMData _data, IPLMToken _token) {
        data = _data;
        token = _token;
    }

    function generateSeed(uint256 tokenId)
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

    // TODO: this requirement is not right
    function generateRandomSlotNonce()
        external
        view
        override
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(blockhash(block.number - 1)));
    }

    function _generateRandomnessFromBlockHash(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - 1), tokenId)
                )
            );
    }

    function getRandomSlotTokenId(bytes32 nonce, bytes32 playerSeed)
        external
        returns (uint256 tokenId)
    {
        tokenId =
            uint256(keccak256(abi.encodePacked(nonce, playerSeed))) %
            token.getTotalSupply();
        return tokenId;
    }
}
