// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMBattleManager} from "../src/PLMBattleManager.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";
import {PLMBattleChoice} from "src/PLMBattleChoice.sol";
import {PLMBattlePlayerSeed} from "src/PLMBattlePlayerSeed.sol";
import {PLMBattleReporter} from "src/PLMBattleReporter.sol";
import {PLMBattleStarter} from "src/PLMBattleStarter.sol";
import {PLMBattleStorage} from "../src/PLMBattleStorage.sol";
import {PLMTypesV1} from "../src/data-contracts/PLMTypesV1.sol";
import {PLMLevelsV1} from "../src/data-contracts/PLMLevelsV1.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMBattleManager} from "../src/interfaces/IPLMBattleManager.sol";
import {IPLMMatchOrganizer} from "../src/interfaces/IPLMMatchOrganizer.sol";
import {IPLMBattleField} from "../src/interfaces/IPLMBattleField.sol";
import {IPLMBattleStorage} from "../src/interfaces/IPLMBattleStorage.sol";
import {IPLMTypes} from "../src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "../src/interfaces/IPLMLevels.sol";

contract BattleTest is Test {
    // FIXME: 定数はハードコードせずにbattleFieldを参照するべき．
    uint256 constant PLAYER_SEED_COMMIT_TIME_LIMIT = 600;
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 600;
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 600;
    uint256 currentBlock = 0;
    uint256 maticForEx = 100000 ether;
    address polylemmer = address(10);

    address home = address(11);
    address visitor = address(12);
    address user3 = address(13);
    address user4 = address(14);

    PLMCoin coinContract;
    PLMToken tokenContract;
    PLMDealer dealerContract;
    PLMData dataContract;
    PLMTypesV1 typesContract;
    PLMLevelsV1 levelsContract;

    IPLMToken token;
    IPLMCoin coin;
    IPLMDealer dealer;
    IPLMData data;
    IPLMTypes types;
    IPLMLevels levels;
    IPLMBattleStorage strg;
    IPLMBattleManager manager;

    PLMBattleStorage strgContract;
    PLMBattleManager managerContract;
    PLMMatchOrganizer mo;
    PLMBattleChoice battleChoice;
    PLMBattlePlayerSeed battlePlayerSeed;
    PLMBattleReporter battleReporter;
    PLMBattleStarter battleStarter;

    /// for battle
    bytes32 bindingFactor1 = bytes32("sdaskfjdiopfvj0pr2904738cdf");
    bytes32 bindingFactor2 = bytes32("sdasfjdiopfvj0pr2904738cdf");

    bytes32 playerSeed1 = bytes32("sdaskfkfjdiopasdasdasdasdf");
    bytes32 playerSeed2 = bytes32("sdakfj34879346fvdsd8cdf");

    function setUp() public {
        // send transaction by deployer
        vm.startPrank(polylemmer);

        // deploy contract
        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));
        typesContract = new PLMTypesV1();
        types = IPLMTypes(address(typesContract));
        levelsContract = new PLMLevelsV1();
        levels = IPLMLevels(address(levelsContract));
        dataContract = new PLMData(types, levels);
        data = IPLMData(address(dataContract));
        tokenContract = new PLMToken(coin, data, 100000);
        token = IPLMToken(address(tokenContract));

        strgContract = new PLMBattleStorage();
        strg = IPLMBattleStorage(address(strgContract));
        managerContract = new PLMBattleManager(token, strg);
        manager = IPLMBattleManager(address(managerContract));
        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));
        mo = new PLMMatchOrganizer(dealer, token);
        battleChoice = new PLMBattleChoice(dealer, token, manager);
        battlePlayerSeed = new PLMBattlePlayerSeed(dealer, token, manager);
        battleReporter = new PLMBattleReporter(dealer,token,manager);
        battleStarter = new PLMBattleStarter(dealer, token, manager);

        // set dealer
        coin.setDealer(address(dealerContract));
        token.setDealer(address(dealerContract));
        dealer.setMatchOrganizer(address(mo));
        dealer.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));
        mo.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));
        battleChoice.setPLMMatchOrganizer(address(mo));
        battlePlayerSeed.setPLMMatchOrganizer(address(mo));
        battleReporter.setPLMMatchOrganizer(address(mo));
        battleStarter.setPLMMatchOrganizer(address(mo));

        manager.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));
        strg.setBattleManager(address(manager));

        vm.stopPrank();

        // initial mint of PLM
        uint256 ammount = 1e20;
        vm.prank(polylemmer);
        dealerContract.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(home, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(home);
        dealerContract.charge{value: maticForEx}();

        //Prepare characters for debug
        bytes20[4] memory names1 = [bytes20("a1"), "a2", "a3", "a4"];
        bytes20[4] memory names2 = [bytes20("b1"), "b2", "b3", "b4"];
        bytes20[4] memory names3 = [bytes20("c1"), "c2", "c3", "c4"];
        uint8[4] memory levels1 = [1, 2, 2, 8]; // sum: 13
        uint8[4] memory levels2 = [3, 4, 5, 2]; // sum: 14
        uint8[4] memory levels3 = [10, 11, 10, 4]; // sum: 35

        // home
        for (uint256 i = 0; i < names1.length; i++) {
            _createCharacter(levels1[i], names1[i], home);
        }

        // visitor
        for (uint256 i = 0; i < names2.length; i++) {
            _createCharacter(levels2[i], names2[i], visitor);
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
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);

        // get proposal
        vm.prank(visitor);
        PLMMatchOrganizer.BattleProposal[] memory homeProposal = mo
            .getProposalList();

        assertEq(homeProposal[0].home, home);
        assertEq(homeProposal[0].upperBound, 20);
        assertEq(homeProposal[0].lowerBound, 10);
        assertEq(homeProposal[0].totalLevel, 17);

        assertTrue(mo.isProposed(home));
    }

    function testFailProposalByNonSubscPlayer() public {
        _createProposalByhome(10, 20);
    }

    function testChallenge() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);

        uint256[4] memory fixedSlotsOfvisitor;
        for (uint256 i = 0; i < token.balanceOf(visitor); i++) {
            fixedSlotsOfvisitor[i] = token.tokenOfOwnerByIndex(visitor, i);
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(visitor);
        mo.requestChallenge(home, fixedSlotsOfvisitor);

        assertTrue(mo.isInBattle(home), "home state is not InBattle");
        assertTrue(mo.isInBattle(visitor), "visitor state is not ");
    }

    function testFailChallengeByNonSubscPlayer() public {
        _freeSubscribe(home);
        _createProposalByhome(10, 20);

        uint256[4] memory fixedSlotsOfvisitor;
        for (uint256 i = 0; i < token.balanceOf(visitor); i++) {
            fixedSlotsOfvisitor[i] = token.tokenOfOwnerByIndex(visitor, i);
        }
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(visitor);
        mo.requestChallenge(home, fixedSlotsOfvisitor);
    }

    // fail test because of level condition
    function testFailChallengeBecauseOfLevel() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);

        uint256[4] memory fixedSlotsOfvisitor;
        for (uint256 i = 0; i < token.balanceOf(user3); i++) {
            fixedSlotsOfvisitor[i] = token.tokenOfOwnerByIndex(user3, i);
        }
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        vm.prank(user3);
        mo.requestChallenge(home, fixedSlotsOfvisitor);
    }

    function testCancelProposal() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);

        assertTrue(mo.isProposed(home));

        vm.prank(home);
        mo.cancelProposal();
        assertTrue(mo.isNotInvolved(home));

        _createProposalByhome(10, 20);
    }

    ////////////////////////////////
    /// TESTS ABOUT BATTLE       ///
    ////////////////////////////////

    // FIXME:
    // test startBattle func
    // function testStartBattle() public {
    //     _freeSubscribe(home);
    //     _freeSubscribe(visitor);
    //     _createProposalByhome(10, 20);
    //     _requestChallengeByvisitor();
    // }

    function testCommitPlayerSeed() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is home, Bob is visitor
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitString1);
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitString2);
    }

    // if committing by other user
    function testFailCommitPlayerSeed() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        bytes32 commitString1 = "asda23124sdafada121234325u42dq"; //30 chars
        bytes32 commitString2 = "sddgfsgkhfjlvhdda121dfdsfds2dq"; //30 chars
        // Alice is home, Bob is visitor
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitString1);

        battlePlayerSeed.commitPlayerSeed(commitString2);
    }

    // 正常終了する手順でバトルを実行する
    // 正常終了： _settleBattleが呼ばれる
    // BattleState  : Settled // 4
    // BattleResult : BattleResultへの書き込みは正常終了した時のみ行われる．
    function testProperBattleFlow() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        IPLMBattleField.Choice[5] memory choices1 = [
            IPLMBattleField.Choice.Fixed2, //1
            IPLMBattleField.Choice.Fixed1, //0
            IPLMBattleField.Choice.Random, //4
            IPLMBattleField.Choice.Fixed3, //2
            IPLMBattleField.Choice.Fixed4 //3
        ];
        IPLMBattleField.Choice[5] memory choices2 = [
            IPLMBattleField.Choice.Random, //4
            IPLMBattleField.Choice.Fixed3, //2
            IPLMBattleField.Choice.Fixed4, //3
            IPLMBattleField.Choice.Fixed2, //1
            IPLMBattleField.Choice.Fixed1 //0
        ];
        uint8[5] memory aliceLevelPoints = [2, 2, 1, 1, 2];
        uint8[5] memory bobLevelPoints = [1, 1, 1, 1, 1];

        _properBattleFlowTester(
            choices1,
            choices2,
            aliceLevelPoints,
            bobLevelPoints
        );

        IPLMBattleField.BattleState bs = manager.getBattleStateById(
            manager.getLatestBattle(home)
        );
        assertEq(uint256(bs), 4, "BattleState is invalid.");
    }

    // test prohibition of the account who committed over level points
    // TODO: If the way of calculation level Point is changed, this test have to support that
    function testCommitOverLevel() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();
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
        // home party level [1,2,2,8] so max level is 8. the first alice's commit of level point is 10, larger than 8.
        uint8[5] memory aliceLevelPoints = [10, 2, 1, 1, 2];
        uint8[5] memory bobLevelPoints = [1, 1, 1, 1, 1];
        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(home);
        _battleFlowWithReverting(
            aliceChoices,
            bobChoices,
            aliceLevelPoints,
            bobLevelPoints
        );

        // cancelBattle
        assertEq(
            5,
            uint256(manager.getBattleState(home)),
            "battle state is not canceled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(home) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to choose a character choosed before is banned
    function testChoiceAgain() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();
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
        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(home);
        _battleFlowWithReverting(
            aliceChoices,
            bobChoices,
            aliceLevelPoints,
            bobLevelPoints
        );

        // cancelBattle
        assertEq(
            5,
            uint256(manager.getBattleState(home)),
            "battle state is not Canceled"
        );
        assertEq(
            5,
            uint256(manager.getBattleState(visitor)),
            "battle state is not Canceled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(home) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to commit seed with delay is banned
    function testLateSeedCommitter() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(home);

        // home(late) commit playerSeed
        currentBlock += uint256(PLAYER_SEED_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);

        // cancelBattle
        assertEq(
            5,
            uint256(manager.getBattleState(home)),
            "battle state is not canceled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(home) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to commit choice with delay is banned
    function testLateChoiceCommitter() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        IPLMBattleField.BattleState currentBattleState;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        //
        currentBattleState = manager.getBattleState(home);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(visitor);
        try battleChoice.commitChoice(commitChoiceString2) {} catch {
            return;
        }

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(home);

        currentBlock += uint256(CHOICE_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        vm.prank(home);
        try battleChoice.commitChoice(commitChoiceString1) {} catch {
            return;
        }

        // cancelBattle
        assertEq(
            5,
            uint256(manager.getBattleState(home)),
            "battle state is not canceld"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(home) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    /// @notice test that the player who tried to reveal choice commit with delay is banned
    function testLateChoiceRevealer() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        IPLMBattleField.BattleState currentBattleState;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        //
        currentBattleState = manager.getBattleState(home);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit properly
        vm.prank(home);
        try battleChoice.commitChoice(commitChoiceString1) {} catch {
            return;
        }
        vm.prank(visitor);
        try battleChoice.commitChoice(commitChoiceString2) {} catch {
            return;
        }

        // reveal choice
        vm.prank(visitor);
        try
            battleChoice.revealChoice(
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        {} catch {
            return;
        }

        uint256 subscBlockBeforeBanned = dealer.getSubscExpiredBlock(home);

        vm.prank(visitor);
        try
            battleChoice.revealChoice(
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        {} catch {
            return;
        }

        currentBlock += uint256(CHOICE_COMMIT_TIME_LIMIT) + 1;
        vm.roll(currentBlock);
        vm.prank(home);
        battleReporter.reportLateReveal();

        // cancelBattle
        assertEq(
            5,
            uint256(manager.getBattleState(home)),
            "battle state is not canceled"
        );

        // banAccount
        assertTrue(
            dealer.getSubscExpiredBlock(home) < subscBlockBeforeBanned,
            "ban of account is not succeed"
        );
    }

    function testFailFlyingCommit() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(1),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );

        //// irregular ////
        // commit choice
        vm.prank(home);
        battleChoice.commitChoice(commitChoiceString1);
    }

    function testFailCommitPlayerSeedAgain() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        //// irregular ////
        // commit player seed again
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
    }

    function testFailCommitChoiceAgain() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(visitor);
        battleChoice.commitChoice(commitChoiceString2);

        //// irregular ////
        // commit choice again
        vm.prank(visitor);
        battleChoice.commitChoice(commitChoiceString2);
    }

    function testFailFlyingReveal() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(visitor);
        battleChoice.commitChoice(commitChoiceString2);

        //// irregular ////
        // flying reveal choice
        battleChoice.revealChoice(
            uint8(2),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor2
        );
    }

    function testFailMismatchReveal() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(home);
        battleChoice.commitChoice(commitChoiceString2);
        vm.prank(visitor);
        battleChoice.commitChoice(commitChoiceString2);

        //// irregular ////
        // mismatch reveal
        battleChoice.revealChoice(
            uint8(1),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor2
        );
    }

    function testFailFlyingCommitAfterReveal() public {
        _freeSubscribe(home);
        _freeSubscribe(visitor);
        _createProposalByhome(10, 20);
        _requestChallengeByvisitor();

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        // pack commit string
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor1
            )
        );
        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                visitor,
                uint8(2),
                IPLMBattleField.Choice.Fixed1,
                bindingFactor2
            )
        );

        // commit HONEST choice
        vm.prank(home);
        battleChoice.commitChoice(commitChoiceString2);
        vm.prank(visitor);
        battleChoice.commitChoice(commitChoiceString2);

        // reveal
        battleChoice.revealChoice(
            uint8(2),
            IPLMBattleField.Choice.Fixed1,
            bindingFactor1
        );

        // pack commit string
        commitChoiceString1 = keccak256(
            abi.encodePacked(
                home,
                uint8(2),
                IPLMBattleField.Choice.Fixed2,
                bindingFactor1
            )
        );

        //// irregular ////
        // flying commit choice
        vm.prank(home);
        battleChoice.commitChoice(commitChoiceString2);
    }

    ////////////////////////////////
    /// UTILS FOR TESTS          ///
    ////////////////////////////////

    function _createProposalByhome(uint16 lower, uint16 upper) internal {
        // home(home) fixedslot
        uint256[4] memory fixedSlotsOfhome = _createFixedSlots(home);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // propose battle
        vm.prank(home);
        mo.proposeBattle(lower, upper, fixedSlotsOfhome);
    }

    function _requestChallengeByvisitor() internal {
        uint256[4] memory fixedSlotsOfvisitor = _createFixedSlots(visitor);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // request battle
        vm.prank(visitor);
        mo.requestChallenge(home, fixedSlotsOfvisitor);
    }

    function _createFixedSlots(
        address user
    ) internal view returns (uint256[4] memory) {
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
            coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
            token.updateLevel(tokenId, 1);
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

    // FIXME: try catchにしているせいで，commitとかでエラーしてもtestが通るようになってしまっている．

    function _properBattleFlowTester(
        IPLMBattleField.Choice[5] memory aliceChoices,
        IPLMBattleField.Choice[5] memory bobChoices,
        uint8[5] memory aliceLevelPoints,
        uint8[5] memory bobLevelPoints
    ) public {
        IPLMBattleField.BattleState currentBattleState;
        uint256 roundCount = 0;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);

        currentBattleState = manager.getBattleState(home);
        while (
            currentBattleState == IPLMBattleField.BattleState.InRound &&
            roundCount < 5
        ) {
            // pack commit string
            bytes32 commitChoiceString1 = keccak256(
                abi.encodePacked(
                    home,
                    aliceLevelPoints[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            );
            bytes32 commitChoiceString2 = keccak256(
                abi.encodePacked(
                    visitor,
                    bobLevelPoints[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            );

            // commit choice
            vm.prank(home);
            battleChoice.commitChoice(commitChoiceString1);
            vm.prank(visitor);
            battleChoice.commitChoice(commitChoiceString2);

            // if choice commit is random slot, revealing of player seed is needed
            if (aliceChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(home);
                battlePlayerSeed.revealPlayerSeed(playerSeed1);
            }
            if (bobChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(visitor);
                battlePlayerSeed.revealPlayerSeed(playerSeed2);
            }
            // reveal choice
            vm.prank(home);
            battleChoice.revealChoice(
                aliceLevelPoints[roundCount],
                aliceChoices[roundCount],
                bindingFactor1
            );
            vm.prank(visitor);
            battleChoice.revealChoice(
                bobLevelPoints[roundCount],
                bobChoices[roundCount],
                bindingFactor2
            );

            currentBattleState = manager.getBattleState(home);

            roundCount++;
        }
    }

    function _battleFlowWithReverting(
        IPLMBattleField.Choice[5] memory aliceChoices,
        IPLMBattleField.Choice[5] memory bobChoices,
        uint8[5] memory aliceLevelPoints,
        uint8[5] memory bobLevelPoints
    ) public {
        IPLMBattleField.BattleState currentBattleState;
        uint256 roundCount = 0;

        // pack commit seed string
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(home, playerSeed1)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(visitor, playerSeed2)
        );

        // home commit playerSeed
        console.log(uint256(manager.getBattleState(home)));
        vm.prank(home);
        battlePlayerSeed.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(visitor);
        battlePlayerSeed.commitPlayerSeed(commitSeedString2);
        currentBattleState = manager.getBattleState(home);
        while (
            currentBattleState == IPLMBattleField.BattleState.InRound &&
            roundCount < 5
        ) {
            // pack commit string
            bytes32 commitChoiceString1 = keccak256(
                abi.encodePacked(
                    home,
                    aliceLevelPoints[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            );
            bytes32 commitChoiceString2 = keccak256(
                abi.encodePacked(
                    visitor,
                    bobLevelPoints[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            );

            // commit choice
            vm.prank(home);
            try battleChoice.commitChoice(commitChoiceString1) {} catch {
                return;
            }
            vm.prank(visitor);
            try battleChoice.commitChoice(commitChoiceString2) {} catch {
                return;
            }

            // if choice commit is random slot, revealing of player seed is needed
            if (aliceChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(home);
                try battlePlayerSeed.revealPlayerSeed(playerSeed1) {} catch {
                    return;
                }
            }
            if (bobChoices[roundCount] == IPLMBattleField.Choice.Random) {
                vm.prank(visitor);
                try battlePlayerSeed.revealPlayerSeed(playerSeed2) {} catch {
                    return;
                }
            }
            // reveal choice
            vm.prank(home);
            try
                battleChoice.revealChoice(
                    aliceLevelPoints[roundCount],
                    aliceChoices[roundCount],
                    bindingFactor1
                )
            {} catch {
                return;
            }
            vm.prank(visitor);
            try
                battleChoice.revealChoice(
                    bobLevelPoints[roundCount],
                    bobChoices[roundCount],
                    bindingFactor2
                )
            {} catch {
                return;
            }
            currentBattleState = manager.getBattleState(home);
            roundCount++;
        }
    }
}
