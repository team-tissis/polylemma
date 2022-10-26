// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMGacha} from "../src/PLMGacha.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMSeeder} from "../src/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";

import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";

contract PLMGachaTest is Test {
    PLMData dataContract;
    PLMSeeder seederContract;
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMGacha gacha;

    IPLMData data;
    IPLMSeeder seeder;
    IPLMToken token;
    IPLMCoin coin;

    IPLMToken.CharacterInfo characterInfo;

    address dealer = address(1);
    address tmpMinter = address(10);
    address treasury = address(11);
    address user = address(100);

    uint256 maxSupplyChar = 10000;
    uint256 initialMintCoin = 100000000;
    uint256 gachaPayment = 5;

    function setUp() public {
        dataContract = new PLMData();
        seederContract = new PLMSeeder();
        seeder = IPLMSeeder(address(seederContract));
        data = IPLMData(address(dataContract));

        tokenContract = new PLMToken(
            dealer,
            tmpMinter,
            seeder,
            data,
            maxSupplyChar
        );
        coinContract = new PLMCoin(treasury, initialMintCoin, user);

        token = IPLMToken(address(tokenContract));
        coin = IPLMCoin(address(coinContract));

        gacha = new PLMGacha(token, coin, treasury, gachaPayment);
        vm.prank(dealer);
        token.setMinter(address(gacha));

        // send enough ERC20 token to gacha to user address
        vm.prank(treasury);
        coin.transfer(user, 100);
    }

    function testGachaCanMint() public {
        // usual user
        vm.prank(user);
        coin.approve(address(gacha), gachaPayment);
        vm.prank(user);
        uint256 gachaResult = gacha.gacha();
        assertEq(1, gachaResult);
        assertEq(1, token.totalSupply());
    }
}
