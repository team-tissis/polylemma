// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

interface IPolylemmaSeeder {
    struct Seed {
        uint48 character;
        uint48 ability;
    }

    function generateSeed(uint256 polyleId) external view returns (Seed memory);
}
