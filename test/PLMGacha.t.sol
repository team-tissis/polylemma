// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMGacha} from "../src/PLMGacha.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMExchange} from "../src/PLMExchange.sol";
import {PLMSeeder} from "../src/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";

import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMExchange} from "../src/interfaces/IPLMExchange.sol";

contract PLMGachaTest is Test {
    PLMData dataContract;
    PLMSeeder seederContract;
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMExchange coinExchangeContract;
    PLMGacha gacha;

    IPLMData data;
    IPLMSeeder seeder;
    IPLMToken token;
    IPLMCoin coin;
    IPLMExchange coinExchange;

    IPLMToken.CharacterInfo characterInfo;

    address dealer = address(1);
    address tmpMinter = address(10);
    address tmpTreasury = address(9);
    address user = address(100);
    uint256 subscFee = 10;
    uint256 subscDuration = 600000;

    uint256 maxSupplyChar = 10000;
    uint256 initialMintCoin = 100000000;
    uint256 gachaPayment = 5;

    function setUp() public {
        vm.startPrank(dealer);

        dataContract = new PLMData();
        seederContract = new PLMSeeder();
        seeder = IPLMSeeder(address(seederContract));
        data = IPLMData(address(dataContract));

        coinContract = new PLMCoin(data, tmpTreasury, subscFee, subscDuration);
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(
            tmpMinter,
            seeder,
            data,
            coin,
            maxSupplyChar
        );
        coinExchangeContract = new PLMExchange(data, coin);
        coinExchange = IPLMExchange(address(coinExchangeContract));

        token = IPLMToken(address(tokenContract));

        gacha = new PLMGacha(token, coin, gachaPayment);

        token.setMinter(address(gacha));
        coin.setTreasury(address(coinExchange));
        coinExchange.mintForTreasury(initialMintCoin);
        vm.stopPrank();

        // send enough ERC20 token to gacha to user address
        vm.prank(address(coinExchange));
        coin.transfer(user, 10000);
    }

    function testGachaCanMint() public {
        // usual user
        //debug

        vm.prank(user);
        coin.approve(address(gacha), gachaPayment);
        vm.prank(user);
        bytes32 name = "test-mon";
        gacha.gacha(name);
        uint256 tokenUsers = token.tokenOfOwnerByIndex(user, 0);
        assertEq(tokenUsers, 1);
        assertEq(1, token.totalSupply());
    }
}
