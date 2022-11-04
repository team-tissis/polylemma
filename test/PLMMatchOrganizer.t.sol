// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";
import {PLMBattleField} from "../src/subcontracts/PLMBattleField.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "../src/interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "../src/interfaces/IPLMMatchOrganizer.sol";

contract PLMMatchOrganizerTest is Test {
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
    PLMBattleField bf;

    /// for battle
    bytes32 bindingFactor1 = bytes32("sdaskfjdiopfvj0pr2904738cdf");
    bytes32 bindingFactor2 = bytes32("sdasfjdiopfvj0pr2904738cdf");

    bytes32 playerSeed1 = bytes32("sdaskfkfjdiopasdasdasdasds738cdf");
    bytes32 playerSeed2 = bytes32("sdakfj34879346fvdsdasds738cdf");

    function setUp() public {
        // send transaction by deployer
        vm.startPrank(polylemmer);

        // deploy contract
        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(coin, 100000);
        token = IPLMToken(address(tokenContract));

        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));
        mo = new PLMMatchOrganizer(dealer, token);
        bf = new PLMBattleField(dealer, token);

        // set dealer
        coin.setDealer(address(dealerContract));
        token.setDealer(address(dealerContract));
        dealer.setMatchOrganizer(address(mo));
        mo.setIPLMBattleField(IPLMBattleField(address(bf)), address(bf));
        bf.setIPLMMatchOrganizer(IPLMMatchOrganizer(address(mo)), address(mo));

        // set block number to be enough length
        currentBlock = dealerContract.getStaminaMax() * 300 + 1000;
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

        /// blindfactor
    }

    ////////////////////////////////
    /// TESTS ABOUT MATCHMAKE    ///
    ////////////////////////////////
    function testProposeBattle() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);

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

    function testFailProposalByNonSubscPlayer() public {
        _createProposalByUser1(10, 20);
    }

    function testChallenge() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);

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
        //assertEq(mo.getProposalList()[0].proposer, address(0), "cc");
    }

    function testFailChallengeByNonSubscPlayer() public {
        _freeSubscribe(user1);
        _createProposalByUser1(10, 20);

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
    }

    function testChallengeBecauseOfExpiredProposal() public {
        _freeSubscribe(user1);
        vm.roll(currentBlock + dealer.getSubscUnitPeriodBlockNum() + 1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);

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
        // TODO: ensure deleting proposal.
    }

    // fail test because of level condition
    function testFailChallengeBecauseOfLevel() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);

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

    function testCancelProposal() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);

        assertTrue(mo.isInProposal(user1));

        vm.prank(user1);
        mo.cancelProposal();
        assertTrue(mo.isNonProposal(user1));

        _createProposalByUser1(10, 20);
    }

    ////////////////////////////////
    /// TESTS ABOUT BATTLE       ///
    ////////////////////////////////

    // test startBattle func
    function testStartBattle() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);
        _requestChallengeByUser2(user1);
    }

    function testCommitPlayerSeed() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);
        _requestChallengeByUser2(user1);

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is proposer, Bob is challenger
        vm.prank(user1);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Alice, commitString1);
        vm.prank(user2);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Bob, commitString2);

        // while
        // aliceCommitChoice = keccak256(
        //     abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor1)
        // );
        // mo.commitChoice(playerId, commitString);
    }

    // if committing by other user
    function testFailCommitPlayerSeed() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);
        _requestChallengeByUser2(user1);

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is proposer, Bob is challenger
        vm.prank(user2);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Alice, commitString1);
        vm.prank(user1);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Bob, commitString2);
    }

    function testProperBattleFlow() public {
        _freeSubscribe(user1);
        _freeSubscribe(user2);
        _createProposalByUser1(10, 20);
        _requestChallengeByUser2(user1);

        IPLMBattleField.Choice[5] memory choices1 = [
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed2,
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed3,
            IPLMBattleField.Choice.Fixed4
        ];
        IPLMBattleField.Choice[5] memory choices2 = [
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed4,
            IPLMBattleField.Choice.Fixed2,
            IPLMBattleField.Choice.Fixed3
        ];
        uint8[5] memory aliceLevelList = [2, 2, 1, 1, 2];
        uint8[5] memory bobLevelList = [1, 1, 1, 1, 1];

        _properBattleFlowTester(
            choices1,
            choices2,
            aliceLevelList,
            bobLevelList
        );
    }

    ////////////////////////////////
    /// UTILS FOR TESTS          ///
    ////////////////////////////////

    function _createProposalByUser1(uint16 lower, uint16 upper) internal {
        // user1(Proposer) fixedslot
        uint256[4] memory fixedSlotsOfProposer = _createFixedSlots(user1);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // propose battle
        vm.prank(user1);
        mo.proposeBattle(lower, upper, fixedSlotsOfProposer);
    }

    function _requestChallengeByUser2(address proposer) internal {
        uint256[4] memory fixedSlotsOfChallenger = _createFixedSlots(user2);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // request battle
        vm.prank(user2);
        mo.requestChallenge(proposer, fixedSlotsOfChallenger);
    }

    function _createFixedSlots(address user)
        internal
        view
        returns (uint256[4] memory)
    {
        uint256[4] memory fixedSlots;
        for (uint256 i = 0; i < token.balanceOf(user); i++) {
            fixedSlots[i] = token.tokenOfOwnerByIndex(user, i);
        }
        return fixedSlots;
    }

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

    function _freeSubscribe(address user) internal {
        vm.startPrank(address(dealerContract));
        coin.transfer(user, dealer.getSubscFeePerUnitPeriod());
        vm.stopPrank();

        vm.startPrank(user);
        coin.approve(
            address(dealerContract),
            dealer.getSubscFeePerUnitPeriod()
        );
        dealer.extendSubscPeriod();
        vm.stopPrank();
    }

    function _properBattleFlowTester(
        IPLMBattleField.Choice[5] memory aliceChoices,
        IPLMBattleField.Choice[5] memory bobChoices,
        uint8[5] memory aliceLevelList,
        uint8[5] memory bobLevelList
    ) public {
        PLMBattleField.BattleState currentBattleState;
        uint256 roundCount = 0;

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(user1, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(user2, playerSeed2)
        );

        // user1 commit playerSeed
        vm.prank(user1);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // user2 commit playerSeed
        vm.prank(user2);
        bf.commitPlayerSeed(bob, commitSeedString2);

        currentBattleState = bf.getBattleState();
        while (
            currentBattleState != IPLMBattleField.BattleState.Settled &&
            roundCount < 5
        ) {
            // pack commit string
            bytes32 commitChoiceString1 = keccak256(
                abi.encodePacked(
                    user1,
                    aliceLevelList[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            );
            bytes32 commitChoiceString2 = keccak256(
                abi.encodePacked(
                    user2,
                    bobLevelList[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            );

            // commit choice
            vm.prank(user1);
            bf.commitChoice(alice, commitChoiceString1);
            vm.prank(user2);
            bf.commitChoice(bob, commitChoiceString2);

            // if choice commit is random slot, revealing of player seed is needed
            if (aliceChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(user1);
                bf.revealPlayerSeed(alice, playerSeed1);
            }
            if (bobChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(user2);
                bf.revealPlayerSeed(bob, playerSeed2);
            }
            // reveal choice
            vm.prank(user1);
            bf.revealChoice(
                alice,
                aliceLevelList[roundCount],
                aliceChoices[roundCount],
                bindingFactor1
            );
            vm.prank(user2);
            bf.revealChoice(
                bob,
                bobLevelList[roundCount],
                bobChoices[roundCount],
                bindingFactor2
            );

            currentBattleState = bf.getBattleState();
            roundCount++;
        }
    }
}
