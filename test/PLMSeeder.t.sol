// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";
import {PLMSeeder} from "../src/lib/PLMSeeder.sol";
import {PLMData} from "../src/subcontracts/PLMData.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";

contract PLMSeederTest is Test {
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
        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(coin, 100000);
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

        // // user1
        // for (uint256 i = 0; i < names1.length; i++) {
        //     _createCharacter(levels1[i], names1[i], user1);
        // }

        // // user2
        // for (uint256 i = 0; i < names2.length; i++) {
        //     _createCharacter(levels2[i], names2[i], user2);
        // }

        // // user3
        // for (uint256 i = 0; i < names3.length; i++) {
        //     _createCharacter(levels3[i], names3[i], user3);
        // }
    }

    uint256 constant trialNum = 100;

    function testGenerateSeed() public {
        uint256 tokenId = 1;

        string[trialNum] memory generatedTypes;
        uint8[trialNum] memory generatedAttributes;

        for (uint256 i = 0; i < trialNum; i++) {
            tokenId++;
            currentBlock++;
            vm.roll(currentBlock);
            PLMSeeder.Seed memory seed = PLMSeeder.generateTokenSeed(
                tokenId,
                IPLMData(address(tokenContract))
            );
            string[] memory characterTypes = IPLMData(address(tokenContract))
                .getCharacterTypes();
            IPLMData.CharacterInfo memory minted = IPLMData.CharacterInfo(
                1,
                1,
                1,
                block.number,
                [seed.attribute],
                "a",
                characterTypes[seed.characterType]
            );
            generatedAttributes[i] = minted.attributeIds[0];
            // generatedAbility[i] = minted.abilityIds[0];
            console.log(minted.attributeIds[0]);
        }

        // console.log(generatedAbility);
    }
}
