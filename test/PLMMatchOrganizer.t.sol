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
import {IPLMMatchOrganizer} from "../src/interfaces/IPLMMatchOrganizer.sol";
import {IPLMBattleField} from "../src/interfaces/IPLMBattleField.sol";

contract BattleTest is Test {
    uint256 constant PLAYER_SEED_COMMIT_TIME_LIMIT = 15;
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 30;
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 15;
    uint256 currentBlock = 0;
    uint256 maticForEx = 100000 ether;
    address polylemmer = address(10);

    address proposer = address(11);
    address challenger = address(12);
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
        dealer.setBattleField(address(bf));
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
        vm.deal(proposer, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(proposer);
        dealerContract.charge{value: maticForEx}();

        //Prepare characters for debug
        bytes20[4] memory names1 = [bytes20("a1"), "a2", "a3", "a4"];
        bytes20[4] memory names2 = [bytes20("b1"), "b2", "b3", "b4"];
        bytes20[4] memory names3 = [bytes20("c1"), "c2", "c3", "c4"];
        uint8[4] memory levels1 = [1, 2, 2, 8]; // sum: 13
        uint8[4] memory levels2 = [3, 4, 5, 2]; // sum: 14
        uint8[4] memory levels3 = [10, 11, 10, 4]; // sum: 35

        // proposer
        for (uint256 i = 0; i < names1.length; i++) {
            _createCharacter(levels1[i], names1[i], proposer);
        }

        // challenger
        for (uint256 i = 0; i < names2.length; i++) {
            _createCharacter(levels2[i], names2[i], challenger);
        }

        // user3
        for (uint256 i = 0; i < names3.length; i++) {
            _createCharacter(levels3[i], names3[i], user3);
        }
    }

    ////////////////////////////////
    /// TESTS ABOUT MATCHMAKE    ///
    ////////////////////////////////

    function testProposeBattle() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);

        // get proposal
        vm.prank(challenger);
        PLMMatchOrganizer.BattleProposal[] memory proposerProposal = mo
            .getProposalList();

        assertEq(proposerProposal[0].proposer, proposer);
        assertEq(proposerProposal[0].upperBound, 20);
        assertEq(proposerProposal[0].lowerBound, 10);
        assertEq(proposerProposal[0].totalLevel, 17);

        assertTrue(mo.isInProposal(proposer));
    }

    function testFailProposalByNonSubscPlayer() public {
        _createProposalByproposer(10, 20);
    }

    function testChallenge() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);

        uint256[4] memory fixedSlotsOfChallenger;
        for (uint256 i = 0; i < token.balanceOf(challenger); i++) {
            fixedSlotsOfChallenger[i] = token.tokenOfOwnerByIndex(
                challenger,
                i
            );
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(challenger);
        mo.requestChallenge(proposer, fixedSlotsOfChallenger);

        assertTrue(mo.isInBattle(proposer), "proposer state is not InBattle");
        assertTrue(mo.isInBattle(challenger), "challenger state is not ");
    }

    function testFailChallengeByNonSubscPlayer() public {
        _freeSubscribe(proposer);
        _createProposalByproposer(10, 20);

        uint256[4] memory fixedSlotsOfChallenger;
        for (uint256 i = 0; i < token.balanceOf(challenger); i++) {
            fixedSlotsOfChallenger[i] = token.tokenOfOwnerByIndex(
                challenger,
                i
            );
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(challenger);
        mo.requestChallenge(proposer, fixedSlotsOfChallenger);
    }

    function testChallengeBecauseOfExpiredProposal() public {
        _freeSubscribe(proposer);
        vm.roll(currentBlock + dealer.getSubscUnitPeriodBlockNum() + 1);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);

        uint256[4] memory fixedSlotsOfChallenger;
        for (uint256 i = 0; i < token.balanceOf(challenger); i++) {
            fixedSlotsOfChallenger[i] = token.tokenOfOwnerByIndex(
                challenger,
                i
            );
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(challenger);
        mo.requestChallenge(proposer, fixedSlotsOfChallenger);
        // TODO: ensure deleting proposal.
    }

    // fail test because of level condition
    function testFailChallengeBecauseOfLevel() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);

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
        mo.requestChallenge(proposer, fixedSlotsOfChallenger);
    }

    function testCancelProposal() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);

        assertTrue(mo.isInProposal(proposer));

        vm.prank(proposer);
        mo.cancelProposal();
        assertTrue(mo.isNonProposal(proposer));

        _createProposalByproposer(10, 20);
    }

    ////////////////////////////////
    /// TESTS ABOUT BATTLE       ///
    ////////////////////////////////

    // test startBattle func
    function testStartBattle() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();
    }

    function testCommitPlayerSeed() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is proposer, Bob is challenger
        vm.prank(proposer);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Alice, commitString1);
        vm.prank(challenger);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Bob, commitString2);
    }

    // if committing by other user
    function testFailCommitPlayerSeed() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is proposer, Bob is challenger
        vm.prank(challenger);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Alice, commitString1);
        vm.prank(proposer);
        bf.commitPlayerSeed(IPLMBattleField.PlayerId.Bob, commitString2);
    }

    function testProperBattleFlow() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

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
        uint8[5] memory aliceLevelPoints = [2, 2, 1, 1, 2];
        uint8[5] memory bobLevelPoints = [1, 1, 1, 1, 1];

        _properBattleFlowTester(
            choices1,
            choices2,
            aliceLevelPoints,
            bobLevelPoints
        );
    }

    // test prohibition of the account who committed over level points
    // TODO: If the way of calculationog level Point is changed, this test have to support that
    function testCommitOverLevel() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();
        IPLMBattleField.Choice[5] memory aliceChoices = [
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed2,
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed3,
            IPLMBattleField.Choice.Fixed4
        ];
        IPLMBattleField.Choice[5] memory bobChoices = [
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed4,
            IPLMBattleField.Choice.Fixed2,
            IPLMBattleField.Choice.Fixed3
        ];
        // proposer party level [1,2,2,8] so max level is 8. the first alice's commit of level point is 10, larger than 8.
        uint8[5] memory aliceLevelPoints = [10, 2, 1, 1, 2];
        uint8[5] memory bobLevelPoints = [1, 1, 1, 1, 1];
        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(proposer);
        _properBattleFlowTester(
            aliceChoices,
            bobChoices,
            aliceLevelPoints,
            bobLevelPoints
        );

        // cancelBattle
        assertEq(
            0,
            uint256(bf.getBattleState()),
            "battle state is not Settled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(proposer) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to choose a character choosed before is banned
    function testChoiceAgain() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();
        IPLMBattleField.Choice[5] memory aliceChoices = [
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed1, // choice again
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed3,
            IPLMBattleField.Choice.Fixed4
        ];
        IPLMBattleField.Choice[5] memory bobChoices = [
            IPLMBattleField.Choice.Random,
            IPLMBattleField.Choice.Fixed1,
            IPLMBattleField.Choice.Fixed4,
            IPLMBattleField.Choice.Fixed2,
            IPLMBattleField.Choice.Fixed3
        ];
        uint8[5] memory aliceLevelPoints = [2, 2, 1, 1, 2];
        uint8[5] memory bobLevelPoints = [1, 1, 1, 1, 1];
        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(proposer);
        _properBattleFlowTester(
            aliceChoices,
            bobChoices,
            aliceLevelPoints,
            bobLevelPoints
        );

        // cancelBattle
        assertEq(
            0,
            uint256(bf.getBattleState()),
            "battle state is not Settled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(proposer) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to commit seed with delay is banned
    function testLazySeedCommitter() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(proposer);

        // proposer(lazy) commit playerSeed
        currentBlock += uint256(PLAYER_SEED_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);

        // cancelBattle
        assertEq(
            0,
            uint256(bf.getBattleState()),
            "battle state is not Settled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(proposer) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to commit choice with delay is banned
    function testLazyChoiceCommitter() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        PLMBattleField.BattleState currentBattleState;

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        //
        currentBattleState = bf.getBattleState();

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(challenger);
        try bf.commitChoice(bob, commitChoiceString2) {} catch {
            return;
        }

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(proposer);

        currentBlock += uint256(CHOICE_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        vm.prank(proposer);
        try bf.commitChoice(alice, commitChoiceString1) {} catch {
            return;
        }

        // cancelBattle
        assertEq(
            0,
            uint256(bf.getBattleState()),
            "battle state is not Settled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(proposer) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to reveal choice commit with delay is banned
    function testLazyChoiceRevealer() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        PLMBattleField.BattleState currentBattleState;

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        //
        currentBattleState = bf.getBattleState();

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit properly
        vm.prank(proposer);
        try bf.commitChoice(alice, commitChoiceString1) {} catch {
            return;
        }
        vm.prank(challenger);
        try bf.commitChoice(bob, commitChoiceString2) {} catch {
            return;
        }

        // reveal choice
        vm.prank(challenger);
        try
            bf.revealChoice(
                bob,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        {} catch {
            return;
        }

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(proposer);

        vm.prank(challenger);
        try
            bf.revealChoice(
                bob,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        {} catch {
            return;
        }

        currentBlock += uint256(CHOICE_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        bf.reportLazyRevealment(bob);

        // cancelBattle
        assertEq(
            0,
            uint256(bf.getBattleState()),
            "battle state is not Settled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(proposer) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    function testFailFlyingCommit() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(1),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );

        //// irregular ////
        // commit choice
        vm.prank(proposer);
        bf.commitChoice(alice, commitChoiceString1);
    }

    function testFailCommitPlayerSeedAgain() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        //// irregular ////
        // commit player seed again
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
    }

    function testFailCommitChoiceAgain() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(challenger);
        bf.commitChoice(bob, commitChoiceString2);

        //// irregular ////
        // commit choice again
        vm.prank(challenger);
        bf.commitChoice(bob, commitChoiceString2);
    }

    function testFailFlyingReveal() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(challenger);
        bf.commitChoice(bob, commitChoiceString2);

        //// irregular ////
        // flying reveal choice
        bf.revealChoice(
            bob,
            uint8(2),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor2
        );
    }

    function testFailMismatchReveal() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(proposer);
        bf.commitChoice(alice, commitChoiceString2);
        vm.prank(challenger);
        bf.commitChoice(bob, commitChoiceString2);

        //// irregular ////
        // mismatch reveal
        bf.revealChoice(
            bob,
            uint8(1),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor2
        );
    }

    function testFailFlyingCommitAfterReveal() public {
        _freeSubscribe(proposer);
        _freeSubscribe(challenger);
        _createProposalByproposer(10, 20);
        _requestChallengeBychallenger();

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                challenger,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(proposer);
        bf.commitChoice(alice, commitChoiceString2);
        vm.prank(challenger);
        bf.commitChoice(bob, commitChoiceString2);

        // reveal
        bf.revealChoice(
            alice,
            uint8(2),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor1
        );

        // pack commit string
        commitChoiceString1 = keccak256(
            abi.encodePacked(
                proposer,
                uint8(2),
                IPLMBattleField.Choice.Fixed2,
                bindingFactor1
            )
        );

        //// irregular ////
        // flying commit choice
        vm.prank(proposer);
        bf.commitChoice(alice, commitChoiceString2);
    }

    ////////////////////////////////
    /// UTILS FOR TESTS          ///
    ////////////////////////////////

    function _createProposalByproposer(uint16 lower, uint16 upper) internal {
        // proposer(Proposer) fixedslot
        uint256[4] memory fixedSlotsOfProposer = _createFixedSlots(proposer);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // propose battle
        vm.prank(proposer);
        mo.proposeBattle(lower, upper, fixedSlotsOfProposer);
    }

    function _requestChallengeBychallenger() internal {
        uint256[4] memory fixedSlotsOfChallenger = _createFixedSlots(
            challenger
        );
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // request battle
        vm.prank(challenger);
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
        uint8[5] memory aliceLevelPoints,
        uint8[5] memory bobLevelPoints
    ) public {
        PLMBattleField.BattleState currentBattleState;
        uint256 roundCount = 0;

        IPLMBattleField.PlayerId alice = IPLMBattleField.PlayerId.Alice;
        IPLMBattleField.PlayerId bob = IPLMBattleField.PlayerId.Bob;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(proposer, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(challenger, playerSeed2)
        );

        // proposer commit playerSeed
        vm.prank(proposer);
        bf.commitPlayerSeed(alice, commitSeedString1);
        // challenger commit playerSeed
        vm.prank(challenger);
        bf.commitPlayerSeed(bob, commitSeedString2);

        currentBattleState = bf.getBattleState();
        while (
            currentBattleState != IPLMBattleField.BattleState.Settled &&
            roundCount < 5
        ) {
            // pack commit string
            bytes32 commitChoiceString1 = keccak256(
                abi.encodePacked(
                    proposer,
                    aliceLevelPoints[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            );
            bytes32 commitChoiceString2 = keccak256(
                abi.encodePacked(
                    challenger,
                    bobLevelPoints[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            );

            // commit choice
            vm.prank(proposer);
            try bf.commitChoice(alice, commitChoiceString1) {} catch {
                return;
            }
            vm.prank(challenger);
            try bf.commitChoice(bob, commitChoiceString2) {} catch {
                return;
            }

            // if choice commit is random slot, revealing of player seed is needed
            if (aliceChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(proposer);
                try bf.revealPlayerSeed(alice, playerSeed1) {} catch {
                    return;
                }
            }
            if (bobChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(challenger);
                try bf.revealPlayerSeed(bob, playerSeed2) {} catch {
                    return;
                }
            }
            // reveal choice
            vm.prank(proposer);
            try
                bf.revealChoice(
                    alice,
                    aliceLevelPoints[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            {} catch {
                return;
            }
            vm.prank(challenger);
            try
                bf.revealChoice(
                    bob,
                    bobLevelPoints[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            {} catch {
                return;
            }

            currentBattleState = bf.getBattleState();
            roundCount++;
        }
    }
}
