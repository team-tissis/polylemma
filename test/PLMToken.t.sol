// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMDealer} from "../src/PLMDealer.sol";
import {PLMCoin} from "../src/PLMCoin.sol";
import {PLMToken} from "../src/PLMToken.sol";

import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";

contract PLMTokenTest is Test {
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
        coinContract = new PLMCoin(address(99));
        coin = IPLMCoin(address(coinContract));
        tokenContract = new PLMToken(address(99), coin, 100000);
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

    function testMintWithCheckPoint() public {
        uint256 tokenId = 1;

        // check empty checkpoint impl
        PLMToken.CharacterInfo memory checkpointBeforeMint = token
            .getCurrentCharacterInfo(tokenId);

        assertEq(checkpointBeforeMint.name, "");
        assertEq(checkpointBeforeMint.characterType, "");
        assertEq(checkpointBeforeMint.level, 0);
        assertEq(checkpointBeforeMint.rarity, 0);
        assertEq(checkpointBeforeMint.abilityIds[0], 0);

        // check impl. of first checkpoint created by mint
        vm.startPrank(user);
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");
        PLMToken.CharacterInfo memory checkpointAfterMint = token
            .getCurrentCharacterInfo(tokenId);

        assertEq(checkpointAfterMint.name, "test-mon");
        assertEq(checkpointAfterMint.level, 1);
    }

    function testLevelUpWithCheckPoint() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);

        assertEq(token.getCurrentCharacterInfo(tokenId).level, 2);
    }

    function testGetPriorCheckPoint() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        coin.approve(address(token), token.getNecessaryExp(tokenId));
        token.updateLevel(tokenId);

        assertEq(
            token.getPriorCharacterInfo(tokenId, currentBlock - 1).level,
            1
        );
        assertEq(token.getCurrentCharacterInfo(tokenId).level, 2);
    }

    function testUpdatelevelSeveralTime() public {
        uint256 tokenId = 1;

        vm.startPrank(user);
        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        dealer.gacha("test-mon");

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        for (uint256 i = 0; i < 10; i++) {
            coin.approve(address(token), token.getNecessaryExp(tokenId));
            token.updateLevel(tokenId);
        }
    }
}
