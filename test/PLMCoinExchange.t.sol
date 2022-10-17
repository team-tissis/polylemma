// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMExchange} from "../src/PLMExchange.sol";

contract PLMExchangeTest is Test {
    // EOA
    IPLMCoin coin;
    IPLMData data;

    PLMData dataContract = new PLMData();
    PLMExchange coinEx;
    address user = address(1000);
    address tmpTreasury = address(99999);

    uint256 initialMint = 100000000;
    uint256 subscFee = 10;
    uint256 subscDuration = 600000;

    function setUp() public {
        data = IPLMData(address(dataContract));
        PLMCoin coinContract = new PLMCoin(
            data,
            tmpTreasury,
            subscFee,
            subscDuration
        );
        coin = IPLMCoin(address(coinContract));
        coinEx = new PLMExchange(data, coin);
        coin.setTreasury(address(coinEx));
        coinEx.mintForTreasury(initialMint);
    }

    function testCoinMintByUser() public {
        vm.startPrank(user);
        vm.deal(user, 1000 ether);
        uint256 maticForEx = 1000;
        uint256 preBalance = coin.balanceOf(address(coinEx));
        coinEx.mintPLMByUser{value: maticForEx}();
        assert(coin.balanceOf(user) != 0);
        assert(coin.balanceOf(address(coinEx)) >= preBalance);
    }
}
