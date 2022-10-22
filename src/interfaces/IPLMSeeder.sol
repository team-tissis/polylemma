// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PolylemmaSeeder

import {IPLMData} from "./IPLMData.sol";

interface IPLMSeeder {
    struct Seed {
        uint8 characterType;
        uint8 ability;
    }

    function generateSeed(uint256 tokenId, IPLMData data)
        external
        view
        returns (Seed memory);

    function generateRandomSlotNonce() external view returns (uint256);
}
