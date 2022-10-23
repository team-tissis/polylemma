// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import {PLMGacha} from "../src/PLMGacha.sol";
// import {PLMToken} from "../src/PLMToken.sol";
// import {PLMCoin} from "../src/PLMCoin.sol";

// import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
// import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";

// contract PLMGachaTest is Test {
//     PLMGacha gacha;
//     PLMToken tokenContract;
//     PLMCoin coinContract;

//     IPLMToken token = IPLMToken(address(tokenContract));
//     IPLMCoin coin = IPLMCoin(address(coinContract));
//     IPLMToken.CharacterInfo characterInfo;

//     uint256 tokenId;
//     address minter = address(10);

//     function setUp() public {
//         gacha = new PLMGacha(token, coin, 10);
//         tokenContract = new PLMToken();
//         coinContract = new PLMCoin();
//     }

//     function testOwnerOfMintedByGacha() public {
//         vm.prank(address(10));
//         tokenId = gacha.gacha();
//         assertEq(token.ownerOf(tokenId), address(10));

//         // characterInfo = token.getCharacterInfo(tokenId);
//     }
// }
