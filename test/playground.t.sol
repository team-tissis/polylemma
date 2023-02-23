// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

contract Playground is Test {
    function setUp() public {}

    function testPlayground() public {
        uint256 a256 = 255;
        uint16 a16 = 255;
        uint8 a8 = 255;
        bool bi = true;
        // bool
        // address
        // string

        bytes memory b256 = abi.encode(a256);
        bytes memory b16 = abi.encode(a16);
        bytes memory b8 = abi.encode(a8);
        bytes memory biByte = abi.encode(bi);

        console.logBytes(b256);
        console.logBytes(b16);
        console.logBytes(b8);
        console.logBytes(biByte);
    }
}
