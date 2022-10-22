// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PlmToken} from "../src/PlmToken.sol";
import {IPlmSeeder} from "../src/interfaces/IPlmSeeder.sol";
import {IPlmData} from "../src/interfaces/IPlmData.sol";

contract PlmTokenTest is Test {
    address iseeder = address(1337);
    address idata = address(1338);
    IPlmSeeder seeder = IPlmSeeder(iseeder);
    IPlmData data = IPlmData(idata);
    PlmToken token;

    function setUp() public {
        token = new PlmToken(msg.sender, seeder, data, 10000);
    }

    function testFailMintByNonMMiner() public {
        vm.prank(address(0));
        token.mint();
    }
}
