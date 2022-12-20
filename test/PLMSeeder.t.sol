// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./subcontracts/TestUtils.sol";

import "../src/lib/PLMSeeder.sol";

contract PLMSeederTest is Test, TestUtils {
    /////////////////////////////
    //   utilities for test   ///
    /////////////////////////////
    uint256 maticForEx = 100000 ether;

    uint256 constant trialNum = 100;

    address user1 = address(11);
    address user2 = address(12);
    address user3 = address(13);
    address user4 = address(14);

    /////////////////////////////
    //           TESTS        ///
    /////////////////////////////
    function setUp() public {
        ///@dev initializing contracts, interfaces and some parameters for test
        baseSetUp();

        // initial mint of PLM
        uint256 ammount = 1e20;
        vm.prank(polylemmer);
        dealer.mintAdditionalCoin(ammount);

        // send ether to user address
        vm.deal(user1, 10000000 ether);
        // (user)  charge MATIC and get PLMcoin
        vm.prank(user1);
        dealer.charge{value: maticForEx}();
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
