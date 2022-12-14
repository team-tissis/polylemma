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
        // TODO: 画像は属性や特性と比較して総数が多いため、現行の実装を踏襲するとものによって排出確率を変更する実装が汚くなってしまうから、一旦一様分布で対応する。
        uint256 pseudoRandomnessImg = _generateRandomnessFromBlockHash(tokenId);
        uint256 numImg = data.getNumImg();

        uint256 pseudoRandomnessType = _generateRandomnessFromBlockHash(
            tokenId + 1
        );
        uint8[] memory cumulativeCharacterTypeOdds = data
            .getCumulativeCharacterTypeOdds();

        uint256 pseudoRandomnessAttribute = _generateRandomnessFromBlockHash(
            tokenId + 2
        );
        uint8[] memory cumulativeAttributeOdds = data
            .getCumulativeAttributeOdds();

        return
            Seed({
                imgId: (pseudoRandomnessImg % numImg) + 1,
                characterType: _matchRandomnessWithOdds(
                    pseudoRandomnessType,
                    cumulativeCharacterTypeOdds
                ),
                attribute: _matchRandomnessWithOdds(
                    pseudoRandomnessAttribute,
                    cumulativeAttributeOdds
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

    /// @notice Only the cumulativeOdds stores cumulative probabilities.
    /// This function calc Id from the array with pseudoRandomness
    function _matchRandomnessWithOdds(
        uint256 pseudoRandomness,
        uint8[] memory cumulativeOdds
    ) internal pure returns (uint8) {
        uint8 sumOdds = cumulativeOdds[cumulativeOdds.length - 1];
        uint256 p = pseudoRandomness % sumOdds;
        if (p < cumulativeOdds[0]) return 0;
        for (uint8 i = 1; i < cumulativeOdds.length; i++) {
            if (cumulativeOdds[i - 1] <= p && p < cumulativeOdds[i]) {
                return i;
            }
        }
        return 0;
    }
}
