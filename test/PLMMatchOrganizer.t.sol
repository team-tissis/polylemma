// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";

contract PLMTokenTest is Test {
    uint32 currentBlock = 0;
    uint256 maticForEx = 100000 ether;
    address polylemmer = address(10);

    address user1 = address(11);
    address user2 = address(12);
    address user3 = address(13);
    address user4 = address(14);

    PLMCoin coinContract;
    PLMToken tokenContract;
    PLMDealer dealerContract;

    IPLMToken token;
    IPLMCoin coin;
    IPLMDealer dealer;

    PLMMatchOrganizer mo;

    function setUp() public {
        // send transaction by deployer
        vm.startPrank(polylemmer);

        // deploy contract
        coinContract = new PLMCoin(address(99));
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(address(99), coin, 100000);
        token = IPLMToken(address(tokenContract));

        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));
        mo = new PLMMatchOrganizer(dealer, token);

        // set dealer
        coin.setDealer(address(dealerContract));
        token.setDealer(address(dealerContract));

        // set block number to be enough length
        currentBlock = dealerContract.getStaminaMax() + 1000;
        vm.roll(currentBlock);
        vm.stopPrank();

        // initial mint of PLM
        uint256 ammount = 1e20;
        vm.prank(polylemmer);
        dealerContract.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(user1, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(user1);
        dealerContract.charge{value: maticForEx}();

        //Prepare characters for debug
        bytes20[4] memory names1 = [bytes20("a1"), "a2", "a3", "a4"];
        bytes20[4] memory names2 = [bytes20("b1"), "b2", "b3", "b4"];
        bytes20[4] memory names3 = [bytes20("c1"), "c2", "c3", "c4"];
        uint8[4] memory levels1 = [1, 2, 2, 8]; // sum: 13
        uint8[4] memory levels2 = [3, 4, 5, 2]; // sum: 14
        uint8[4] memory levels3 = [10, 11, 10, 4]; // sum: 35

        // user1
        for (uint256 i = 0; i < names1.length; i++) {
            _createCharacter(levels1[i], names1[i], user1);
        }

        // user2
        for (uint256 i = 0; i < names2.length; i++) {
            _createCharacter(levels2[i], names2[i], user2);
        }

        // user3
        for (uint256 i = 0; i < names3.length; i++) {
            _createCharacter(levels3[i], names3[i], user3);
        }
    }

    function testProposeBattle() public {
        _createProposalByUser1();

        // get proposal
        vm.prank(user2);
        PLMMatchOrganizer.BattleProposal[] memory user1Proposal = mo
            .getProposalList();

        assertEq(user1Proposal[0].proposer, user1);
        assertEq(user1Proposal[0].upperBound, 20);
        assertEq(user1Proposal[0].lowerBound, 10);
        assertEq(user1Proposal[0].totalLevel, 17);

        assertTrue(mo.isInProposal(user1));
    }

    event Log(PLMMatchOrganizer.BattleProposal[] props);

    function testChallenge() public {
        _createProposalByUser1();

        uint256[4] memory fixedSlotsOfChallenger;
        for (uint256 i = 0; i < token.balanceOf(user2); i++) {
            fixedSlotsOfChallenger[i] = token.tokenOfOwnerByIndex(user2, i);
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(user2);
        mo.requestChallenge(user1, fixedSlotsOfChallenger);

        assertTrue(mo.isInBattle(user1), "aa");
        assertTrue(mo.isInBattle(user2), "bb");
        assertEq(mo.getProposalList()[0].proposer, address(0), "cc");
    }

    // fail test because of level condition
    function testFailChallenge() public {
        _createProposalByUser1();

        uint256[4] memory fixedSlotsOfChallenger;
        for (uint256 i = 0; i < token.balanceOf(user3); i++) {
            fixedSlotsOfChallenger[i] = token.tokenOfOwnerByIndex(user3, i);
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(user3);
        mo.requestChallenge(user1, fixedSlotsOfChallenger);

        assertTrue(mo.isInBattle(user1), "aa");
        assertTrue(mo.isInBattle(user2), "bb");
        assertEq(mo.getProposalList()[0].proposer, address(0), "cc");
    }

    function _createProposalByUser1() internal {
        // user1(Proposer) fixedslot
        uint256[4] memory fixedSlotsOfProposer;
        for (uint256 i = 0; i < token.balanceOf(user1); i++) {
            fixedSlotsOfProposer[i] = token.tokenOfOwnerByIndex(user1, i);
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // propose battle
        vm.prank(user1);
        mo.proposeBattle(10, 20, fixedSlotsOfProposer);
    }

    // for test
    function _createCharacter(
        uint256 lev,
        bytes20 name,
        address owner
    ) internal {
        vm.startPrank(address(dealerContract));
        uint256 tokenId = token.mint(name);
        for (uint256 i; i < lev; i++) {
            coin.approve(address(token), token.getNecessaryExp(tokenId));
            token.updateLevel(tokenId);
        }
        token.transferFrom(address(dealerContract), owner, tokenId);
        vm.stopPrank();
    }
}
