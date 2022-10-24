// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMSeeder} from "../src/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";

import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";

contract PLMTokenTest is Test {
    // EOA
    address dealer = address(1);
    address minter = msg.sender;

    PLMSeeder seederContract;
    PLMData dataContract;
    PLMToken token;

    IPLMSeeder seeder;
    IPLMData data;

    function setUp() public {
        dataContract = new PLMData();
        seederContract = new PLMSeeder();
        seeder = IPLMSeeder(address(seederContract));
        data = IPLMData(address(dataContract));
        uint256 maxSupply = 10000;
        token = new PLMToken(dealer, minter, seeder, data, maxSupply);
    }

    function testMint() public {
        vm.prank(minter);
        token.mint();
    }

    function testFailMintByNonMiner() public {
        vm.prank(address(10)); //set a diffrent address from minter's address to msg.sender
        token.mint();
    }

    function testTokenIdIncrement() public {
        vm.startPrank(minter);
        uint256 aTokenId = token.totalSupply();
        token.mint();
        uint256 nextTokenId = token.totalSupply();
        vm.stopPrank();

        assertEq(aTokenId + 1, nextTokenId);
    }

    function testIsCorrectOwnerMint() public {
        vm.startPrank(minter);
        token.mint();
        uint256 latestTokenId = token.totalSupply();
        address mintedTokenOwner = token.ownerOf(latestTokenId);
        vm.stopPrank();

        assertEq(mintedTokenOwner, minter);
    }

    function testCharacterInfo() public {
        vm.startPrank(minter);
        uint256 tokenId = token.mint();
        PLMToken.CharacterInfo memory tokenInfo = token.getCharacterInfo(
            tokenId
        );
        // check characterInfo initialization

        // TODO: to test other members
        assertEq(tokenInfo.level, 1);
        vm.stopPrank();
    }
}
