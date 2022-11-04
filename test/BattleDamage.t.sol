// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";

contract BattleDamageTest is Test {
    address polylemmer = address(10);
    address user = address(11);
    uint256 maticForEx = 100000 ether;
    uint32 currentBlock = 0;
    PLMDealer dealer;

    PLMCoin coinContract;
    PLMToken tokenContract;
    IPLMToken token;
    IPLMCoin coin;

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

        // set block number to be enough length
        currentBlock = dealer.getStaminaMax() + 1000;
        vm.roll(currentBlock);
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

    function testCalcPower() public {
        uint8 numRounds = 0;
        string[] memory characterTypes = token.getCharacterTypes();
        uint8[] memory attributeRarities = token.getAttributeRarities();

        uint8 player1AttributeId = 0;
        uint8 player1Level = 10;
        PLMToken.CharacterInfo memory player1Char;
        player1Char.name = bytes20("Alice");
        player1Char.characterType = characterTypes[0];
        player1Char.fromBlock = 0;
        player1Char.level = player1Level;
        player1Char.rarity = attributeRarities[player1AttributeId];
        player1Char.attributeIds = [player1AttributeId];
        uint8 player1LevelPoint = 3;

        PLMToken.CharacterInfo memory player2Char;
        player2Char.name = bytes20("Bob");
        player2Char.characterType = characterTypes[0];
        player2Char.fromBlock = 0;
        player2Char.level = player1Level + 1;
        player2Char.rarity = attributeRarities[player1AttributeId];
        player2Char.attributeIds = [player1AttributeId];
        uint8 player2LevelPoint = 2;

        uint32 alicePower = token.calcPower(
            numRounds,
            player1Char,
            player1LevelPoint,
            player2Char
        );
        uint32 bobPower = token.calcPower(
            numRounds,
            player2Char,
            player2LevelPoint,
            player1Char
        );
        assertEq(alicePower, bobPower);
    }
}
