// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import {PLMSeeder} from "../src/PLMSeeder.sol";
// import {PLMData} from "../src/PLMData.sol";

// import {IPLMData} from "../src/interfaces/IPLMData.sol";

// contract PLMSeederTest is Test {
//     PLMSeeder seeder = new PLMSeeder();
//     PLMData dataContract = new PLMData();

//     IPLMData data = IPLMData(address(dataContract));

//     function setUp() public {
//         seeder = new PLMSeeder(data);
//     }

//     function testFailMintByNonMiner() public {
//         vm.prank(address(0));
//         .mint();
//     }
// }
