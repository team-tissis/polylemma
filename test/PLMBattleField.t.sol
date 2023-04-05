// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

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

contract BattleFieldTest is Test {
    address polylemmer = address(10);
    uint256 maticForEx = 100000 ether;
    uint256 currentBlock = 0;

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

    address home = address(11);
    address visitor = address(12);
    address user3 = address(13);

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

        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));

        strgContract = new PLMBattleStorage();
        strg = IPLMBattleStorage(address(strgContract));
        managerContract = new PLMBattleManager(strg);
        manager = IPLMBattleManager(address(managerContract));
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

    function testStartBattle() public {
        currentBlock++;
        vm.roll(currentBlock);
        uint256[4] memory homeFixedSlots = [uint256(1), 2, 3, 4];
        uint256[4] memory visitorFixedSlots = [uint256(5), 6, 7, 8];
        vm.prank(address(mo));
        bf.startBattle(
            home,
            visitor,
            currentBlock,
            currentBlock,
            homeFixedSlots,
            visitorFixedSlots
        );
    }
}
