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
    address minter = address(101);

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
        token = new PLMToken(minter, seeder, data, 10000);
    }

    function testFailMintByNonMiner() public {
        vm.prank(address(0));
        token.mint();
    }
}
