// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMCoin} from "../src/PLMCoin.sol";

contract PLMTokenTest is Test {
    // EOA
    PLMCoin coin;
    uint256 initialMint = 10000;
    address treasury;
    address user = address(199);

    function setUp() public {
        treasury = address(10);
        coin = new PLMCoin(treasury, initialMint, user);
    }

    function testInitialMint() public {
        assertEq(coin.balanceOf(treasury), initialMint);
    }
}
