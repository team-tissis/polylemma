// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPLMData} from "../interfaces/IPLMData.sol";
import {IPLMToken} from "../interfaces/IPLMToken.sol";

library PLMSeeder {
    struct Seed {
        uint8 characterType;
        uint8 ability;
    }

    /// @notice generate seeds for character mint
    /// @dev generate seeds of traits from current-block's hash for to mint character
    /// @param tokenId tokenId to be minted
    /// @return Seed the struct of trait seed that is indexId of trait array
    function generateSeed(uint256 tokenId, IPLMData data)
        external
        view
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

    /// @notice generate nonce to be used as input of hash for randomSlotTokenId
    /// @dev generate nonce to be used as input of hash for randomSlotTokenId
    function generateRandomSlotNonce() external view returns (bytes32) {
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

    /// @notice create tokenId for randomslot without being searched
    /// @dev create tokenId for randomslot without being searched
    /// @param nonce : this prevent players from searching in input space
    /// @return tokenId : tokenId of randomslot
    function getRandomSlotTokenId(
        bytes32 nonce,
        bytes32 playerSeed,
        IPLMToken token
    ) external view returns (uint256) {
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(nonce, playerSeed))
        ) % token.totalSupply();
        return tokenId;
    }
}
