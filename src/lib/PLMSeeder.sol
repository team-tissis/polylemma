// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPLMData} from "../interfaces/IPLMData.sol";
import {IPLMToken} from "../interfaces/IPLMToken.sol";

library PLMSeeder {
    struct Seed {
        uint256 imgId;
        uint8 characterType;
        uint8 attribute;
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
        uint256 numImg = data.getNumImg();
        uint256 numOddsCharacterType = data.getNumOddsCharacterType();
        // TODO: 画像は属性や特性と比較して総数が多いため、現行の実装を踏襲するとものによって排出確率を変更する実装が汚くなってしまうから、一旦一様分布で対応する。
        uint256 numOddsAttribute = data.numOddsAttribute();
        uint8[] memory characterTypeOdds = data.getCharacterTypeOdds();
        uint8[] memory attributeOdds = data.getAttributeOdds();

        return
            Seed({
                imgId: (pseudoRandomness % numImg) + 1,
                characterType: characterTypeOdds[
                    pseudoRandomness % numOddsCharacterType
                ],
                attribute: _calcAttributeSeed(
                    pseudoRandomness,
                    numOddsAttribute,
                    attributeOdds
                )
            });
    }

    /// @notice generate nonce to be used as input of hash for randomSlotTokenId
    /// @dev generate nonce to be used as input of hash for randomSlotTokenId
    /// TODO: 関数名変える
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
        uint256 totalSupply
    ) external pure returns (uint256) {
        uint256 tokenId = (uint256(
            keccak256(abi.encodePacked(nonce, playerSeed))
        ) % totalSupply) + 1;
        return tokenId;
    }

    /// @notice Only the attributeOdds stores cumulative probabilities.
    /// This function calc attribute Id from the array with pseudoRandomness
    function _calcAttributeSeed(
        uint256 pseudoRandomness,
        uint256 numOddsAttribute,
        uint8[] memory attributeOdds
    ) internal pure returns (uint8) {
        // calculation of index of attribute
        uint256 p = pseudoRandomness % numOddsAttribute;
        for (uint8 i; i < attributeOdds.length; i++) {
            if (i == 0) {
                if (p < attributeOdds[i]) {
                    return i;
                } else {
                    continue;
                }
            } else if (attributeOdds[i - 1] <= p && p < attributeOdds[i]) {
                return i;
            }
        }
        return 0;
    }
}
