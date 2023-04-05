// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMTypesV1} from "../src/data-contracts/PLMTypesV1.sol";
import {PLMLevelsV1} from "../src/data-contracts/PLMLevelsV1.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMTypes} from "../src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "../src/interfaces/IPLMLevels.sol";

contract BattleDamageTest is Test {
    address polylemmer = address(10);
    address user = address(11);
    uint256 maticForEx = 100000 ether;
    uint32 currentBlock = 0;
    PLMDealer dealer;

    PLMCoin coinContract;
    PLMToken tokenContract;
    PLMData dataContract;
    PLMTypesV1 typesContract;
    PLMLevelsV1 levelsContract;

    IPLMToken token;
    IPLMCoin coin;
    IPLMData data;
    IPLMTypes types;
    IPLMLevels levels;

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
        dealer = new PLMDealer(token, coin);

        // set dealer
        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));

        vm.stopPrank();

        // initial mint of PLM
        uint256 ammount = 100000000000000;
        vm.prank(polylemmer);
        dealer.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(user, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(user);
        dealer.charge{value: maticForEx}();
    }

    function testCalcDamage() public {
        uint8 numRounds = 0;
        string[] memory characterTypes = data.getCharacterTypes();
        uint8[] memory attributeRarities = data.getAttributeRarities();

        uint8 player1AttributeId = 0;
        uint8 player1Level = 10;
        PLMData.CharacterInfoMinimal memory player1Char;
        player1Char.characterTypeId = 0;
        player1Char.level = player1Level;
        player1Char.attributeIds = [player1AttributeId];
        uint8 player1LevelPoint = 3;
        uint8 player1BondLevel = 1;

        PLMData.CharacterInfoMinimal memory player2Char;
        player2Char.characterTypeId = 0;
        player2Char.level = player1Level + 1;
        player2Char.attributeIds = [player1AttributeId];
        uint8 player2LevelPoint = 2;
        uint8 player2BondLevel = 1;

        uint32 aliceDamage = data.getDamage(
            numRounds,
            player1Char,
            player1LevelPoint,
            player1BondLevel,
            player2Char
        );
        uint32 bobDamage = data.getDamage(
            numRounds,
            player2Char,
            player2LevelPoint,
            player2BondLevel,
            player1Char
        );
        assertEq(aliceDamage, bobDamage);
    }
}
