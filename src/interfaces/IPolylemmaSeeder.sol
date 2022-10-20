// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

import {IPolylemmaData} from "./IPolylemmaData.sol";

interface IPolylemmaSeeder {
    struct Seed {
        uint48 characterType;
        uint48 ability;
    }

    function generateSeed(uint256 tokenId, IPolylemmaData data)
        external
        view
        returns (Seed memory);
}
