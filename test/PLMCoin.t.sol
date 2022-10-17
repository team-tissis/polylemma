// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMCoin} from "../src/PLMCoin.sol";

contract PLMCoinTest is Test {
    // EOA
    PLMCoin coin;
    IPLMData data;

    PLMData dataContract = new PLMData();

    address dealer = address(10);
    address user = address(100);
    address tmpTreasury = address(9);
    address treasury;

    uint256 initialMint = 100000000;
    uint256 subscFee = 10;
    uint256 subscDuration = 600000;

    function setUp() public {
        vm.startPrank(dealer);
        data = IPLMData(address(dataContract));
        coin = new PLMCoin(data, tmpTreasury, subscFee, subscDuration);
        treasury = address(1111);
        coin.setTreasury(treasury);
        vm.stopPrank();

        vm.prank(treasury);
        coin.mint(initialMint);
        vm.prank(treasury);
        coin.transfer(user, 1000);
    }

    function testSubscUpadate() public {
        vm.startPrank(user);
        uint256 b = coin.balanceOf(user);
        uint256 bn = coin.getSubscExpiredPoint(user);
        coin.updateSubsc();
        assert(coin.getSubscExpiredPoint(user) > bn);
        assertEq(coin.balanceOf(user) + coin.getSubscFee(), b);
    }
    // function testInitialMint() public {
    //     assertEq(coin.balanceOf(treasury), initialMint);
    // }
}
