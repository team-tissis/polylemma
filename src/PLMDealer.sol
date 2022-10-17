// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";

contract PLMDealer is IPLMDealer {
    /// @notice interface to the coin
    IPLMCoin coin;

    function payReward(address winner, uint256 amount) external {
        _payReward(winner, amount);
    }

    function _payReward(address winner, uint256 amount) internal {
        coin.transfer(winner, amount);
    }
}
