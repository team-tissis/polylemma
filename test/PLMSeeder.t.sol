// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMMatchOrganizer} from "../src/PLMMatchOrganizer.sol";
import {PLMSeeder} from "../src/lib/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMTypesV1} from "../src/data-contracts/PLMTypesV1.sol";
import {PLMLevelsV1} from "../src/data-contracts/PLMLevelsV1.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMTypes} from "../src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "../src/interfaces/IPLMLevels.sol";

contract PLMSeederTest is Test {
    /////////////////////////////
    //   utilities for test   ///
    /////////////////////////////
    uint32 currentBlock = 0;
    uint256 maticForEx = 100000 ether;
    address polylemmer = address(10);

    uint256 constant trialNum = 100;

    address user1 = address(11);
    address user2 = address(12);
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

    PLMMatchOrganizer mo;

    /////////////////////////////
    //           TESTS        ///
    /////////////////////////////
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
    }

    /// @dev validate that generated seeds value do not violate the range. (100 trial)
    function testGenerateSeed() public {
        uint256 tokenId = 1;

        for (uint256 i = 0; i < trialNum; i++) {
            tokenId++;
            currentBlock++;
            vm.roll(currentBlock);

            PLMSeeder.Seed memory seed = PLMSeeder.generateTokenSeed(
                tokenId,
                token
            );

            uint256 numAttributes = data.getNumAttributes();
            uint256 numCharacterTypes = data.getNumCharacterTypes();
            assertTrue(seed.attribute <= numAttributes);
            assertTrue(seed.characterType <= numCharacterTypes);

            // console.log(minted.attributeIds[0]);
        }
    }

    /// @dev test that randomFromBlockHash works correctly without errors
    /// TODO: 乱数生成が正しく行われているかを検証する方法を知らないため、エラーなく動くかどうかだけ確認。
    function testRandomFromBlockHash() public {
        PLMSeeder.randomFromBlockHash();
    }

    /// @dev test that getRandomSlotTokenId returns currect range value.
    function testGetRandomSlotTokenId() public {
        uint256 nonce = 5;
        uint256 playerSeed = 30;
        uint256 totalSupply = 10;
        uint256 tokenId = PLMSeeder.getRandomSlotTokenId(
            bytes32(nonce),
            bytes32(playerSeed),
            totalSupply
        );
        assertTrue(tokenId <= totalSupply);
    }
}
