// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";

contract PLMCoinTest is Test {
    address polylemmer = address(10);
    address user = address(11);
    address matchOrganizer = address(20);
    uint256 maticForEx = 10 ether;
    PLMDealer dealer;

    PLMCoin coinContract;
    PLMToken tokenContract;
    IPLMCoin coin;
    IPLMToken token;

    function setUp() public {
        // send transaction by deployer
        vm.startPrank(polylemmer);

        // deploy contract
        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(coin, 100000);
        token = IPLMToken(address(tokenContract));

        dealer = new PLMDealer(token, coin);

        // set dealer
        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));
        dealer.setMatchOrganizer(matchOrganizer);

        // set block number to be enough length
        vm.roll(dealer.getStaminaMax() * 300 + 1000);
        console.log("hoge");
        vm.stopPrank();

        // initial mint of PLM
        uint256 ammount = 100000;
        vm.prank(polylemmer);
        dealer.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(user, 1000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(user);
        dealer.charge{value: maticForEx}();
    }

    ///////////////////////////////
    /// TESTS STAMINA FUNC.     ///
    ///////////////////////////////
    function testGetCurrentStamina() public {
        vm.startPrank(user);
        assertEq(dealer.getStaminaMax(), dealer.getCurrentStamina(user));
        vm.stopPrank();
    }

    function testConsumeStaminaForBattle() public {
        vm.prank(user);
        uint256 fromStamina = dealer.getCurrentStamina(user);

        vm.prank(matchOrganizer);
        dealer.consumeStaminaForBattle(user);
        vm.startPrank(user);
        assertEq(
            fromStamina - dealer.getStaminaPerBattle(),
            dealer.getCurrentStamina(user),
            "consume stamina failed"
        );
        vm.stopPrank();
    }

    function testRestoreStamina() public {
        vm.prank(address(dealer));
        uint256 fromBalance = coin.balanceOf(user);
        vm.prank(user);
        uint256 fromStamina = dealer.getCurrentStamina(user);
        vm.prank(matchOrganizer);
        dealer.consumeStaminaForBattle(user);
        vm.startPrank(user);
        assertEq(
            fromStamina - dealer.getStaminaPerBattle(),
            dealer.getCurrentStamina(user),
            "consume"
        );
        coin.approve(address(dealer), dealer.getStaminaPerBattle());
        dealer.restoreFullStamina(user);
        assertEq(
            fromBalance - dealer.getRestoreStaminaFee(),
            coin.balanceOf(user)
        );
        vm.stopPrank();
    }

    ////////////////////////////////
    /// TESTS FINANCES FUNC.     ///
    ////////////////////////////////

    ////////////////////////////////
    /// TESTS Subsctiption Func. ///
    ////////////////////////////////
    function testExtendSubsc() public {
        vm.prank(address(dealer));
        coin.transfer(user, 100);
        vm.startPrank(user);
        uint256 b = coin.balanceOf(user);
        uint256 bn = dealer.getSubscExpiredBlock(user);
        coin.approve(address(dealer), dealer.getSubscFeePerUnitPeriod());
        dealer.extendSubscPeriod();
        assert(dealer.getSubscExpiredBlock(user) > bn);
        assertEq(coin.balanceOf(user) + dealer.getSubscFeePerUnitPeriod(), b);
        vm.stopPrank();
    }

    function testBanAccount() public {
        vm.prank(address(dealer));
        coin.transfer(user, 100);
        vm.startPrank(user);
        coin.approve(address(dealer), dealer.getSubscFeePerUnitPeriod());
        dealer.extendSubscPeriod();
        vm.stopPrank();

        uint256 fromSubscExpi = dealer.getSubscExpiredBlock(user);
        vm.prank(polylemmer);
        dealer.banAccount(user, 10);
        assertEq(fromSubscExpi - 10, dealer.getSubscExpiredBlock(user));
    }

    //////////////////////////////////
    /// TESTS CHARGEMENT FUNC.     ///
    //////////////////////////////////
    function testCharge() public {
        vm.startPrank(user);
        uint256 preDealerBalance = coin.balanceOf(address(dealer));
        uint256 preUserBalance = coin.balanceOf(address(user));
        dealer.charge{value: maticForEx}();
        assert(coin.balanceOf(user) > preUserBalance);
        assert(coin.balanceOf(address(dealer)) >= preDealerBalance);
    }
}
