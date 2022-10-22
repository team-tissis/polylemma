// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

import {IPlmData} from "./IPlmData.sol";

interface IPlmSeeder {
    struct Seed {
        uint48 characterType;
        uint48 ability;
    }

    function generateSeed(uint256 tokenId, IPlmData data)
        external
        view
        returns (Seed memory);
}
