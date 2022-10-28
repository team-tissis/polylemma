// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMSeeder} from "../src/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";

import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";

contract PLMTokenTest is Test {
    // EOA
    address dealer = address(100);
    address minter = address(10);

    PLMSeeder seederContract;
    PLMData dataContract;
    PLMCoin coinContract;
    PLMToken token;

    IPLMSeeder seeder;
    IPLMData data;
    IPLMCoin coin;

    function setUp() public {
        vm.startPrank(dealer);
        dataContract = new PLMData();
        seederContract = new PLMSeeder();
        coinContract = new PLMCoin(1000000);
        seeder = IPLMSeeder(address(seederContract));
        data = IPLMData(address(dataContract));
        coin = IPLMCoin(address(coinContract));
        uint256 maxSupply = 10000;
        token = new PLMToken(minter, seeder, data, coin, maxSupply);
        vm.stopPrank();
    }

    function testMint() public {
        vm.prank(minter);
        token.mint();
    }

    function testFailMintByNonMiner() public {
        vm.prank(address(100)); //set a diffrent address from minter's address to msg.sender
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

    function testUpdateLevel() public {
        vm.startPrank(minter);
        uint256 tokenId = token.mint();
        coin.mint(100000);
        coin.approve(
            address(token),
            data.calcNecessaryExp(token.getCharacterInfo(tokenId))
        );
        assertEq(token.getCharacterInfo(tokenId).level, 1, "not initial level");
        token.updateLevel(tokenId);
        token.getCharacterInfo(tokenId);
        assertEq(token.getCharacterInfo(tokenId).level, 2, "level not updated");
    }
}
