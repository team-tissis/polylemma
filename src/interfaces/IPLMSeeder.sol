// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

interface IPLMSeeder {
    struct Seed {
        uint8 characterType;
        uint8 ability;
    }

    function generateSeed(uint256 tokenId) external view returns (Seed memory);

    function generateRandomSlotNonce() external view returns (bytes32);

    function getRandomSlotTokenId(bytes32 nonce, bytes32 playerSeed)
        external
        returns (uint256 tokenId);
}
