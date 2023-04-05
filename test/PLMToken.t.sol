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

contract PLMTokenTest is Test {
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

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }

    function testMultipleGachaAndLevelUp() public {
        vm.startPrank(user);
        uint8 num = 5;
        bytes32[] memory names = new bytes32[](num);
        names[0] = stringToBytes32("test-mon-1");
        names[1] = stringToBytes32("test-mon-2");
        names[2] = stringToBytes32("test-mon-3");
        names[3] = stringToBytes32("test-mon-4");
        names[4] = stringToBytes32("test-mon-5");

        // multiple gacha
        coin.approve(address(dealer), dealer.getGachaFee() * num);
        dealer.gacha(names, num);

        // retrieve character infos
        PLMToken.CharacterInfo memory char1 = token.getCurrentCharacterInfo(1);
        PLMToken.CharacterInfo memory char2 = token.getCurrentCharacterInfo(2);
        PLMToken.CharacterInfo memory char3 = token.getCurrentCharacterInfo(3);
        PLMToken.CharacterInfo memory char4 = token.getCurrentCharacterInfo(4);
        PLMToken.CharacterInfo memory char5 = token.getCurrentCharacterInfo(5);

        // check character names
        assertEq(char1.name, "test-mon-1");
        assertEq(char2.name, "test-mon-2");
        assertEq(char3.name, "test-mon-3");
        assertEq(char4.name, "test-mon-4");
        assertEq(char5.name, "test-mon-5");

        // check character level
        assertEq(char1.level, 1);

        // check single levelup
        coin.approve(address(token), token.getNecessaryExp(2, 1));
        token.updateLevel(2, 1);
        char2 = token.getCurrentCharacterInfo(2);
        assertEq(char2.level, 2);

        // check multiple levelup
        coin.approve(address(token), token.getNecessaryExp(3, 2));
        token.updateLevel(3, 2);
        char3 = token.getCurrentCharacterInfo(3);
        assertEq(char3.level, 3);
    }

    function testMintWithCheckPoint() public {
        uint256 tokenId = 1;

        // check empty checkpoint impl
        PLMToken.CharacterInfo memory checkpointBeforeMint = token
            .getCurrentCharacterInfo(tokenId);

        assertEq(checkpointBeforeMint.name, "");
        assertEq(checkpointBeforeMint.characterTypeId, 0);
        assertEq(checkpointBeforeMint.level, 0);
        assertEq(checkpointBeforeMint.rarity, 0);
        assertEq(checkpointBeforeMint.attributeIds[0], 0);

        // check impl. of first checkpoint created by mint
        vm.startPrank(user);
        coin.approve(address(dealer), dealer.getGachaFee());
        bytes32[] memory names = new bytes32[](1);
        names[0] = stringToBytes32("test-mon");
        dealer.gacha(names, 1);
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
        bytes32[] memory names = new bytes32[](1);
        names[0] = (stringToBytes32("test-mon"));
        dealer.gacha(names, 1);

        // level Up
        coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
        token.updateLevel(tokenId, 1);

        assertEq(token.getCurrentCharacterInfo(tokenId).level, 2);
    }

    function testGetPriorCheckPoint() public {
        uint256 tokenId = 1;

        vm.startPrank(user);

        // debug: if we remove this roll, the below assertion marked by [WARNING] fails.
        currentBlock++;
        vm.roll(currentBlock);

        // gacha
        coin.approve(address(dealer), dealer.getGachaFee());
        bytes32[] memory names = new bytes32[](1);
        names[0] = (stringToBytes32("test-mon"));
        dealer.gacha(names, 1);

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
        token.updateLevel(tokenId, 1);

        // [WARNING]
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
        bytes32[] memory names = new bytes32[](1);
        names[0] = (stringToBytes32("test-mon"));
        dealer.gacha(names, 1);

        // level Up
        currentBlock++;
        vm.roll(currentBlock);
        for (uint256 i = 0; i < 10; i++) {
            coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
            token.updateLevel(tokenId, 1);
        }
    }

    function testImgURI() public {
        uint256 imgId = 1;
        string memory imgURI = token.getImgURI(imgId);
        console.log(imgURI);
    }

    function testTokenURI() public {
        uint256 tokenId = 1;
        vm.startPrank(user);
        coin.approve(address(dealer), dealer.getGachaFee());
        bytes32[] memory names = new bytes32[](1);
        names[0] = (stringToBytes32("test-mon"));
        dealer.gacha(names, 1);

        // Level up and show tokenURI
        string memory tokenURI = token.tokenURI(tokenId);
        console.log(tokenURI);

        // Level up and show tokenURI
        coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
        token.updateLevel(tokenId, 1);
        string memory tokenURI2 = token.tokenURI(tokenId);
        console.log(tokenURI2);

        // Level up and show tokenURI
        coin.approve(address(token), token.getNecessaryExp(tokenId, 1));
        token.updateLevel(tokenId, 1);
        string memory tokenURI3 = token.tokenURI(tokenId);
        console.log(tokenURI3);
    }
}
