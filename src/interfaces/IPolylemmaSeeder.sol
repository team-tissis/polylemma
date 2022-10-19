// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

import {IPolylemmaData} from "./interface/IPolylemmaData.sol";

interface IPolylemmaSeeder {
    struct Seed {
        uint48 character;
        uint48 ability;
    }

    function generateSeed(uint256 polyleId, IPolylemmaData data)
        external
        view
        returns (Seed memory);
}
