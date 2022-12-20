// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./subcontracts/TestUtils.sol";

contract PLMDealerTest is Test, TestUtils {
    address user = address(11);
    uint256 maticForEx = 10 ether;

    ///////////////////////////////
    ///       TESTS UTILS       ///
    ///////////////////////////////

    function _blockNumber() internal view returns (uint256) {
        return currentBlock;
    }

    function _stepBlockNumber() internal {
        currentBlock += 1;
    }

    function _setBlockNumber(uint256 _blockNum) internal returns (uint256) {
        currentBlock = _blockNum;
        return currentBlock;
    }

    function setUp() public {
        initializeTest();

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

    ////////////////////////////////
    /// FUNCTIONS ABOUT FINANCES ///
    ////////////////////////////////

    function testBalanceOfMatic() public {
        vm.deal(address(dealer), 100 ether);
        assertEq(uint256(100 ether), dealer.balanceOfMatic());
    }

    // TODO: failed to send ether (in withdraw func.)
    // function testWithdraw() public {
    //     vm.deal(address(dealer), 100 ether);
    //     vm.prank(polylemmer);
    //     dealer.withdraw(50 ether);
    //     assertEq(uint256(50 ether), dealer.balanceOfMatic());
    // }

    function testMintAdditionalCoin() public {
        uint256 balance = coin.balanceOf(address(dealer));
        vm.prank(polylemmer);
        dealer.mintAdditionalCoin(100);
        assertEq(balance, coin.balanceOf(address(dealer)) - 100);
    }

    ///////////////////////////////
    /// FUNCTIONS ABOUT STAMINA ///
    ///////////////////////////////
    function testGetCurrentStamina() public {
        // current block Number inititialized in setUp
        assertEq(
            dealer.getCurrentStamina(user),
            dealer.getStaminaMax(),
            "stamina initializing or getCurrentStamina failed"
        );
    }

    // TODO:
    // function testRestoreFullStamina() public {
    //     // initialize user balance for test
    //     vm.prank(address(dealer));
    //     coin.transfer(user, 100);
    //     uint256 fromBalance = coin.balanceOf(user);

    //     // consume stamina (validated in other test func.)
    //     vm.prank(matchOrganizer);
    //     dealer.consumeStaminaForBattle(user);

    //     // restore stamina
    //     coin.approve(address(dealer), dealer.getStaminaPerBattle());
    //     dealer.restoreFullStamina(user);
    //     assertEq(
    //         fromBalance - dealer.getRestoreStaminaFee(),
    //         coin.balanceOf(user),
    //         "Payment processing for stamina recovery failed"
    //     );
    //     assertEq(
    //         dealer.getStaminaMax(),
    //         dealer.getCurrentStamina(user),
    //         "stamina full restoring failed"
    //     );
    // }

    function testConsumeStaminaForBattle() public {
        vm.prank(user);
        uint256 fromStamina = dealer.getCurrentStamina(user);

        // consume stamina
        vm.prank(address(mo));
        dealer.consumeStaminaForBattle(user);
        vm.startPrank(user);
        assertEq(
            fromStamina - dealer.getStaminaPerBattle(),
            dealer.getCurrentStamina(user),
            "consuming stamina failed"
        );
        vm.stopPrank();
    }

    function testRestoreStaminaGradually() public {
        vm.prank(user);
        uint8 fromStamina = dealer.getCurrentStamina(user);

        // consume stamina (validated in other test func.)
        vm.prank(address(mo));
        dealer.consumeStaminaForBattle(user);

        _setBlockNumber(_blockNumber() + 350);
        vm.roll(_blockNumber());

        // 300で１回復する。
        assertEq(
            dealer.getCurrentStamina(user),
            fromStamina - dealer.getStaminaPerBattle() + 1,
            "Automatic recovery of stamina over time failed"
        );
    }

    ////////////////////////////////
    /// TESTS Subsctiption Func. ///
    ////////////////////////////////

    function testExtendSubscAndSubscIsExpired() public {
        // subscription is initialized as expired.
        assertTrue(dealer.subscIsExpired(user));

        // initialize user coin balance for test
        vm.prank(address(dealer));
        coin.transfer(user, 100);
        vm.startPrank(user);
        uint256 b = coin.balanceOf(user);

        // extend subsc
        coin.approve(address(dealer), dealer.getSubscFeePerUnitPeriod());
        dealer.extendSubscPeriod();

        assertTrue(!dealer.subscIsExpired(user));
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
        vm.roll(31000 + 43200);
        dealer.charge{value: maticForEx}();
        assert(coin.balanceOf(user) > preUserBalance);
        assert(coin.balanceOf(address(dealer)) >= preDealerBalance);
    }
}
