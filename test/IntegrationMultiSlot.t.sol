// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMBattleManager} from "../src/PLMBattleManager.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";
import {PLMBattleField} from "../src/PLMBattleField.sol";
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

contract MultiSlotTest is Test {
    struct TestPlayer {
        address addr;
        IPLMBattleField.Choice[5] choices;
        uint8[5] levelPoints;
        bytes32 bindingFactor;
        bytes32 playerSeed;
    }

    event Log(string message);

    // FIXME: 定数はハードコードせずにbattleFieldを参照するべき．
    uint256 constant PLAYER_SEED_COMMIT_TIME_LIMIT = 600;
    uint256 constant CHOICE_COMMIT_TIME_LIMIT = 600;
    uint256 constant CHOICE_REVEAL_TIME_LIMIT = 600;
    uint256 currentBlock = 0;
    uint256 maticForEx = 100000 ether;
    address polylemmer = address(10);

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
    PLMBattleField bf;

    TestPlayer home1 =
        TestPlayer(
            address(11),
            [
                IPLMBattleField.Choice.Fixed2, //1
                IPLMBattleField.Choice.Fixed1, //0
                IPLMBattleField.Choice.Random, //4
                IPLMBattleField.Choice.Fixed3, //2
                IPLMBattleField.Choice.Fixed4 //3
            ],
            [2, 2, 1, 1, 2],
            bytes32("sdaskfjdiopfvj0pr2904738cdf"),
            bytes32("sdaskfkfjdiopasdasdasdasds7df")
        );

    TestPlayer visitor1 =
        TestPlayer(
            address(12),
            [
                IPLMBattleField.Choice.Fixed1, //0
                IPLMBattleField.Choice.Random, //4
                IPLMBattleField.Choice.Fixed2, //1
                IPLMBattleField.Choice.Fixed3, //2
                IPLMBattleField.Choice.Fixed4 //3
            ],
            [2, 2, 1, 1, 2],
            bytes32("sdaskfjdiopfvj0prsdas38cdf"),
            bytes32("sdaskdfdshfljldifhbfodvdoi")
        );
    TestPlayer home2 =
        TestPlayer(
            address(21),
            [
                IPLMBattleField.Choice.Fixed2, //1
                IPLMBattleField.Choice.Fixed1, //0
                IPLMBattleField.Choice.Random, //4
                IPLMBattleField.Choice.Fixed3, //2
                IPLMBattleField.Choice.Fixed4 //3
            ],
            [2, 2, 1, 1, 2],
            bytes32("sdaskfjdiopfvj0pr2904738cdf"),
            bytes32("sdaskfkfjdiopasdasdasdasds7df")
        );
    TestPlayer visitor2 =
        TestPlayer(
            address(22),
            [
                IPLMBattleField.Choice.Fixed2, //1
                IPLMBattleField.Choice.Random, //4
                IPLMBattleField.Choice.Fixed3, //2
                IPLMBattleField.Choice.Fixed1, //0
                IPLMBattleField.Choice.Fixed4 //3
            ],
            [2, 2, 1, 1, 2],
            bytes32("sdaskfjdfklsdjfpagr2904738cdf"),
            bytes32("sdaskfdfioqudfsdadfdsdasds7df")
        );

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

        // deploy battle system
        strgContract = new PLMBattleStorage();
        strg = IPLMBattleStorage(address(strgContract));
        managerContract = new PLMBattleManager(token, strg);
        manager = IPLMBattleManager(address(managerContract));
        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));
        mo = new PLMMatchOrganizer(dealer, token);
        bf = new PLMBattleField(dealer, token, manager);

        // set dealer
        coin.setDealer(address(dealerContract));
        token.setDealer(address(dealerContract));
        dealer.setMatchOrganizer(address(mo));
        dealer.setBattleField(address(bf));
        mo.setPLMBattleField(address(bf));
        bf.setPLMMatchOrganizer(address(mo));
        manager.setPLMBattleField(address(bf));
        strg.setBattleManager(address(manager));

        vm.stopPrank();

        // initial mint of PLM
        uint256 ammount = 1e20;
        vm.prank(polylemmer);
        dealerContract.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(home1.addr, 10000000 ether);
        vm.deal(home2.addr, 10000000 ether);
        vm.deal(visitor1.addr, 10000000 ether);
        vm.deal(visitor2.addr, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(home1.addr);
        dealerContract.charge{value: maticForEx}();
        vm.prank(visitor1.addr);
        dealerContract.charge{value: maticForEx}();
        vm.prank(home2.addr);
        dealerContract.charge{value: maticForEx}();
        vm.prank(visitor2.addr);
        dealerContract.charge{value: maticForEx}();

        //Prepare characters for debug
        bytes20[4] memory names1 = [bytes20("a1"), "a2", "a3", "a4"];
        bytes20[4] memory names2 = [bytes20("b1"), "b2", "b3", "b4"];
        bytes20[4] memory names3 = [bytes20("c1"), "c2", "c3", "c4"];
        bytes20[4] memory names4 = [bytes20("d1"), "d2", "d3", "d4"];
        uint8[4] memory levels1 = [1, 2, 2, 8]; // sum: 13
        uint8[4] memory levels2 = [3, 4, 5, 2]; // sum: 14
        uint8[4] memory levels3 = [10, 11, 10, 4]; // sum: 35
        uint8[4] memory levels4 = [3, 4, 2, 8]; // sum: 17

        // home1
        for (uint256 i = 0; i < names1.length; i++) {
            _createCharacter(levels1[i], names1[i], home1);
        }

        // visitor1.addr
        for (uint256 i = 0; i < names2.length; i++) {
            _createCharacter(levels2[i], names2[i], visitor1);
        }

        // home2
        for (uint256 i = 0; i < names3.length; i++) {
            _createCharacter(levels3[i], names3[i], home2);
        }
        for (uint256 i = 0; i < names4.length; i++) {
            _createCharacter(levels4[i], names4[i], visitor2);
        }
    }

    // ２つのバトルが提案された時に，２つのバトルが適切に開始されるかどうか
    // - すでに始まっているバトルに対してrequestChallengeした時，適切にrejectされるか
    // - battle Idで２つのバトルの情報を適切に取得することができるか
    // - battleは２つともはじまるか:state
    // - ２つのバトルを適切に進めることができるか
    // - 間違って他のバトルを参照しようとした時

    // 複数人が同時にバトルを提案した時
    function testMakeProposalByTwo() public {
        _freeSubscribe(home1);
        _freeSubscribe(visitor1);
        _freeSubscribe(home2);
        _freeSubscribe(visitor2);

        // make 2 proposals
        _createProposal(home1, 10, 40);
        _createProposal(home2, 10, 40);

        // get proposal list
        IPLMMatchOrganizer.BattleProposal[] memory proposalList = mo
            .getProposalList();

        assertEq(
            proposalList.length,
            2,
            "Proposal haven't registered properly."
        );

        // valid request
        _requestChallenge(visitor1, home1);
        bool e = true;
        // invalid request, request to proposal already started.
        _requestInvalidChallenge(visitor2, home1);

        _requestChallenge(visitor2, home2);
    }

    function testMultiSlotBattles() public {
        // prevent using just minted character in the same block.
        currentBlock++;
        vm.roll(currentBlock);

        _freeSubscribe(home1);
        _freeSubscribe(visitor1);
        _freeSubscribe(home2);
        _freeSubscribe(visitor2);

        // make 2 proposals
        _createProposal(home1, 10, 40);
        _createProposal(home2, 10, 40);

        // battles start
        _requestChallenge(visitor1, home1);
        _requestChallenge(visitor2, home2);

        _twoBattleThread(home1, visitor1, home2, visitor2);
        // _properTwoBattleFlowsTester(home1, visitor1.addr, home2, visitor2);

        // vm.prank(home1);
        // assertEq(uint256(manager.getBattleState()), 4, "not settled");
        // vm.prank(home2);
        // assertEq(uint256(manager.getBattleState()), 4, "not settled");
    }

    /////////////////////////
    ////     UTILS      /////
    /////////////////////////

    function _freeSubscribe(TestPlayer storage user) internal {
        vm.startPrank(address(dealerContract));
        coin.transfer(user.addr, dealer.getSubscFeePerUnitPeriod());
        vm.stopPrank();

        vm.startPrank(user.addr);
        coin.approve(
            address(dealerContract),
            dealer.getSubscFeePerUnitPeriod()
        );
        dealer.extendSubscPeriod();
        vm.stopPrank();
    }

    function _createCharacter(
        uint256 lev,
        bytes20 name,
        TestPlayer storage _owner
    ) internal {
        vm.startPrank(address(dealerContract));
        uint256 tokenId = token.mint(name);
        for (uint256 i; i < lev; i++) {
            coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
            token.updateLevel(tokenId, 1);
        }

        token.transferFrom(address(dealerContract), _owner.addr, tokenId);
        vm.stopPrank();
    }

    function _createProposal(
        TestPlayer storage _home,
        uint16 lower,
        uint16 upper
    ) internal {
        // home(home) fixedslot
        uint256[4] memory fixedSlotsOfhome = _createFixedSlots(_home);

        currentBlock += 1;
        vm.roll(currentBlock);

        // propose battle
        vm.prank(_home.addr);
        mo.proposeBattle(lower, upper, fixedSlotsOfhome);
    }

    function _requestChallenge(
        TestPlayer storage _visitor,
        TestPlayer storage _home
    ) internal {
        uint256[4] memory fixedSlotsOfvisitor = _createFixedSlots(_visitor);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // request battle
        vm.prank(_visitor.addr);
        mo.requestChallenge(_home.addr, fixedSlotsOfvisitor);
    }

    function _requestInvalidChallenge(
        TestPlayer storage _visitor,
        TestPlayer storage _home
    ) internal {
        uint256[4] memory fixedSlotsOfvisitor = _createFixedSlots(_visitor);
        // pouse to goes by in blocktime
        currentBlock += 1;
        vm.roll(currentBlock);
        currentBlock += 1;
        vm.roll(currentBlock);

        // request battle
        vm.prank(_visitor.addr);
        try mo.requestChallenge(_home.addr, fixedSlotsOfvisitor) {
            revert("invalid request accepted");
        } catch {
            emit Log("invalid request rejected properly");
        }
    }

    function _createFixedSlots(
        TestPlayer storage user
    ) internal view returns (uint256[4] memory) {
        uint256[4] memory fixedSlots;
        for (uint256 i = 0; i < token.balanceOf(user.addr); i++) {
            fixedSlots[i] = token.tokenOfOwnerByIndex(user.addr, i);
        }
        return fixedSlots;
    }

    function _twoBattleThread(
        TestPlayer storage _home1,
        TestPlayer storage _visitor1,
        TestPlayer storage _home2,
        TestPlayer storage _visitor2
    ) internal {
        //// pack commit seed string
        //battle1
        bytes32 commitSeedString1 = keccak256(
            abi.encodePacked(_home1.addr, _home1.playerSeed)
        );
        bytes32 commitSeedString2 = keccak256(
            abi.encodePacked(_visitor1.addr, _visitor1.playerSeed)
        );
        //battle2
        bytes32 commitSeedString3 = keccak256(
            abi.encodePacked(_home2.addr, _home2.playerSeed)
        );
        bytes32 commitSeedString4 = keccak256(
            abi.encodePacked(_visitor2.addr, _visitor2.playerSeed)
        );

        // home commit playerSeed
        vm.prank(_home1.addr);
        bf.commitPlayerSeed(commitSeedString1);
        // visitor commit playerSeed
        vm.prank(_visitor1.addr);
        bf.commitPlayerSeed(commitSeedString2);

        // home commit playerSeed
        vm.prank(_home2.addr);
        bf.commitPlayerSeed(commitSeedString3);
        // visitor commit playerSeed
        vm.prank(_visitor2.addr);
        bf.commitPlayerSeed(commitSeedString4);

        uint8 roundCount = 0;
        IPLMBattleField.BattleState bs1 = manager.getBattleState(_home1.addr);
        IPLMBattleField.BattleState bs2 = manager.getBattleState(_home2.addr);

        while (roundCount < 5) {
            if (bs1 == IPLMBattleField.BattleState.InRound) {
                _round(
                    _home1,
                    _visitor1,
                    commitSeedString1,
                    commitSeedString2,
                    roundCount
                );
            }
            if (bs2 == IPLMBattleField.BattleState.InRound) {
                _round(
                    _home2,
                    _visitor2,
                    commitSeedString3,
                    commitSeedString4,
                    roundCount
                );
            }
            roundCount++;
            bs1 = manager.getBattleState(_home1.addr);
            bs2 = manager.getBattleState(_home2.addr);
        }
    }

    function _round(
        TestPlayer storage _home,
        TestPlayer storage _visitor,
        bytes32 _homeCSS,
        bytes32 _visitorCSS,
        uint8 _roundCount
    ) internal {
        bytes32 commitChoiceString1 = keccak256(
            abi.encodePacked(
                _home.addr,
                _home.levelPoints[_roundCount],
                _home.choices[_roundCount],
                _home.bindingFactor
            )
        );

        bytes32 commitChoiceString2 = keccak256(
            abi.encodePacked(
                _visitor.addr,
                _visitor.levelPoints[_roundCount],
                _visitor.choices[_roundCount],
                _visitor.bindingFactor
            )
        );

        // commit choice
        vm.prank(_home.addr);
        bf.commitChoice(commitChoiceString1);
        vm.prank(_visitor.addr);
        bf.commitChoice(commitChoiceString2);

        if (_home.choices[_roundCount] == IPLMBattleField.Choice.Random) {
            vm.prank(_home.addr);
            bf.revealPlayerSeed(_home.playerSeed);
        }
        if (_visitor.choices[_roundCount] == IPLMBattleField.Choice.Random) {
            vm.prank(_visitor.addr);
            bf.revealPlayerSeed(_visitor.playerSeed);
        }

        vm.prank(_home.addr);
        bf.revealChoice(
            _home.levelPoints[_roundCount],
            _home.choices[_roundCount],
            _home.bindingFactor
        );
        vm.prank(_visitor.addr);
        bf.revealChoice(
            _visitor.levelPoints[_roundCount],
            _visitor.choices[_roundCount],
            _visitor.bindingFactor
        );
    }
}
