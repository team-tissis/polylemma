// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMSeeder} from "../src/PLMSeeder.sol";
import {PLMData} from "../src/PLMData.sol";
import {PLMExchange} from "../src/PLMExchange.sol";

import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMExchange} from "../src/interfaces/IPLMExchange.sol";

contract PLMTokenTest is Test {
    // EOA
    address dealer = address(100);
    address minter = address(10);
    address tmpTreasury = address(9);
    address treasury;
    address user = address(999);

    uint256 initialMint = 10000000;
    uint256 subscFee = 100;
    uint256 subscDuration = 600000;

    PLMSeeder seederContract;
    PLMData dataContract;
    PLMCoin coinContract;
    PLMExchange coinExContract;
    PLMToken token;

    IPLMSeeder seeder;
    IPLMData data;
    IPLMCoin coin;
    IPLMExchange coinEx;

    function setUp() public {
        vm.startPrank(dealer);
        dataContract = new PLMData();
        data = IPLMData(address(dataContract));
        seederContract = new PLMSeeder();
        coinContract = new PLMCoin(data, tmpTreasury, subscFee, subscDuration);
        seeder = IPLMSeeder(address(seederContract));
        coin = IPLMCoin(address(coinContract));
        uint256 maxSupply = 10000;
        token = new PLMToken(minter, seeder, data, coin, maxSupply);

        coinExContract = new PLMExchange(data, coin);
        coinEx = IPLMExchange(address(coinExContract));
        treasury = address(coinEx);
        coin.setTreasury(treasury);
        coinEx.mintForTreasury(100000000);
        vm.stopPrank();
    }

    function testMint() public {
        bytes32 name = "test-mon";
        vm.prank(minter);
        token.mint(name);
    }

    function testFailMintByNonMiner() public {
        bytes32 name = "test-mon";
        vm.prank(address(100)); //set a diffrent address from minter's address to msg.sender
        token.mint(name);
    }

    function testTokenIdIncrement() public {
        vm.startPrank(minter);
        uint256 aTokenId = token.totalSupply();
        bytes32 name = "test-mon";
        token.mint(name);
        uint256 nextTokenId = token.totalSupply();
        vm.stopPrank();

        assertEq(aTokenId + 1, nextTokenId);
    }

    function testIsCorrectOwnerMint() public {
        vm.startPrank(minter);
        bytes32 name = "test-mon";
        token.mint(name);
        uint256 latestTokenId = token.totalSupply();
        address mintedTokenOwner = token.ownerOf(latestTokenId);
        vm.stopPrank();

        assertEq(mintedTokenOwner, minter);
    }

    function testCharacterInfo() public {
        vm.startPrank(minter);
        bytes32 name = "test-mon";
        uint256 tokenId = token.mint(name);
        PLMToken.CharacterInfo memory tokenInfo = token.getCharacterInfo(
            tokenId
        );
        // check characterInfo initialization

        // TODO: to test other members
        assertEq(tokenInfo.level, 1);
        vm.stopPrank();
    }

    function testUpdateLevel() public {
        vm.prank(treasury);
        coin.transfer(user, 10000);

        vm.startPrank(minter);
        bytes32 name = "test-mon";
        uint256 tokenId = token.mint(name);
        token.transferFrom(minter, user, tokenId);
        vm.stopPrank();

        vm.startPrank(user);
        coin.approve(
            address(token),
            data.calcNecessaryExp(token.getCharacterInfo(tokenId))
        );
        assertEq(token.getCharacterInfo(tokenId).level, 1, "not initial level");
        token.updateLevel(tokenId);
        token.getCharacterInfo(tokenId);
        assertEq(token.getCharacterInfo(tokenId).level, 2, "level not updated");
        vm.stopPrank();
    }
}
