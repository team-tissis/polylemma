// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./subcontracts/TestUtils.sol";

contract BattleDamageTest is Test, TestUtils {
    address user = address(11);
    uint256 maticForEx = 100000 ether;

    function setUp() public {
        ///@dev initializing contracts, interfaces and some parameters for test
        initializeTest();

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
