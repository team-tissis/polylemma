// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMCoin} from "../src/PLMCoin.sol";

contract PLMCoinTest is Test {
    address notDealer = address(1);
    address polylemmer = address(10);
    address dealer = address(11);
    PLMCoin coin;

    function setUp() public {
        vm.startPrank(polylemmer);
        coin = new PLMCoin();
        coin.setDealer(dealer);
        vm.stopPrank();
    }

    function testMintByDealer() public {
        uint256 amount = 10000;
        vm.prank(dealer);
        coin.mint(amount);
        assertEq(amount, coin.balanceOf(dealer));
    }

    function testFailMintByNonDealer() public {
        uint256 amount = 10000;
        vm.prank(notDealer);
        coin.mint(amount);
        assertEq(amount, coin.balanceOf(dealer));
    }
}
