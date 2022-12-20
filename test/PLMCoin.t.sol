// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./subcontracts/TestUtils.sol";

contract PLMCoinTest is Test, TestUtils {
    address notDealer = address(13);

    function setUp() public {
        ///@dev initializing contracts, interfaces and some parameters for test
        initializeTest();
    }

    function testMintByDealer() public {
        uint256 amount = 10000;
        vm.prank(address(dealer));
        coin.mint(amount);
        assertEq(amount, coin.balanceOf(address(dealer)));
    }

    function testFailMintByNonDealer() public {
        uint256 amount = 10000;
        vm.prank(notDealer);
        coin.mint(amount);
        assertEq(amount, coin.balanceOf(address(dealer)));
    }
}
