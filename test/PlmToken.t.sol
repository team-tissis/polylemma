// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PLMToken} from "../src/PLMToken.sol";
import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";

contract PLMTokenTest is Test {
    address iseeder = address(1337);
    address idata = address(1338);
    IPLMSeeder seeder = IPLMSeeder(iseeder);
    IPLMData data = IPLMData(idata);
    PLMToken token;

    function setUp() public {
        token = new PLMToken(msg.sender, seeder, data, 10000);
    }

    function testFailMintByNonMMiner() public {
        vm.prank(address(0));
        token.mint();
    }
}
