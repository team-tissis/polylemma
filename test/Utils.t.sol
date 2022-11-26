// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/lib/Utils.sol";

contract UtilsTest is Test {
    function setUp() public {}

    /// @dev example of a function whose all args are uints whose byte size are defferent
    function sum(uint8 a, uint16 b) public pure returns (uint32) {
        return a + b;
    }

    function echo(uint32 a) public pure returns (uint256) {
        return a;
    }

    function testCurry() public {
        uint256[] memory args = new uint256[](2);
        uint8 args0 = 2;
        uint16 args1 = 1;
        args[0] = args0;
        args[1] = args1;

        bytes4 funcSig = bytes4(keccak256("sum(uint8,uint16)"));

        assertEq(
            abi.encodeWithSelector(funcSig, args0, args1),
            Utils.curryUint(funcSig, args)
        );
    }

    /////////////////////////////
    // preparing indexed array //
    /////////////////////////////
    uint256[] searcheeArray = [
        2,
        3,
        9,
        12,
        18,
        21,
        22,
        24,
        29,
        35,
        38,
        39,
        41,
        42,
        46,
        49,
        52
    ];

    /// @dev for bin search test
    function getLength() public view returns (uint256) {
        return searcheeArray.length;
    }

    /// @dev for bin search test
    function getElementByIdx(uint32 index) public view returns (uint256) {
        return searcheeArray[index];
    }

    /// @dev test of binarySearchIdx
    function testBinarySearchIdx() public {
        uint256 targetValue = 34;

        bytes memory getLengthPacked = abi.encodePacked(
            bytes4(keccak256("getLength()"))
        );
        bytes memory getElementPacked = abi.encodePacked(
            bytes4(keccak256("getElementByIdx(uint32)"))
        );
        (uint32 i1, bool result1) = Utils.binarySearchIdx(
            getLengthPacked,
            getElementPacked,
            targetValue,
            address(this)
        );
        assertEq(i1, 8, "searching failed");
        assertEq(result1, true);

        targetValue = 1;
        (uint32 i2, bool result2) = Utils.binarySearchIdx(
            getLengthPacked,
            getElementPacked,
            targetValue,
            address(this)
        );
        assertEq(i2, 0, "searching failed");
        assertEq(result2, false, "target is lower than index 0");
    }

    /// @dev test of getPrior function
    function testGetPriorUtils() public {
        uint256 targetValue = 34;

        uint256[] memory numArgs;
        uint256[] memory elementArgs;

        (uint32 i1, bool result1) = Utils.getPrior(
            targetValue,
            address(this),
            "getLength()",
            "getElementByIdx(uint32)",
            numArgs,
            elementArgs
        );
        assertEq(i1, 8, "searching failed");
        assertEq(result1, true);
    }
}
