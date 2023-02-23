// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

library Utils {
    function getPrior(
        uint256 targetValue,
        address callAddress,
        string memory numFunc,
        string memory elementFunc,
        uint256[] memory numArgs,
        uint256[] memory elementArgs
    ) external view returns (uint32 index, bool found) {
        bytes4 numFuncSig = bytes4((keccak256(abi.encodePacked(numFunc))));
        bytes memory numFuncPacked = curryUint(numFuncSig, numArgs);
        bytes4 elementFuncSig = bytes4(
            (keccak256(abi.encodePacked(elementFunc)))
        );
        bytes memory elementFuncPacked = curryUint(elementFuncSig, elementArgs);
        return
            binarySearchIdx(
                numFuncPacked,
                elementFuncPacked,
                targetValue,
                callAddress
            );
    }

    /// @notice Run binary search in a type of checkpoints.
    /// @dev this function can be used for any checkpoints types.
    function binarySearchIdx(
        bytes memory lengthFuncPacked,
        bytes memory elementFuncPacked,
        uint256 targetValue,
        address funcAddress
    ) public view returns (uint32, bool) {
        uint32 numElements = _callGetLength(lengthFuncPacked, funcAddress);

        if (numElements == 0) {
            return (0, false);
        }

        // First check the most recent
        if (
            _callGetElementByIdx(
                elementFuncPacked,
                numElements - 1,
                funcAddress
            ) <= targetValue
        ) {
            return (numElements - 1, true);
        }

        // Nest check implicit zero
        if (
            _callGetElementByIdx(elementFuncPacked, 0, funcAddress) >
            targetValue
        ) {
            return (0, false);
        }

        /// @notice calc the array index where the targetValue that you want to search is placed by binary search
        uint32 lower = 0;
        uint32 upper = numElements - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            uint256 element = _callGetElementByIdx(
                elementFuncPacked,
                center,
                funcAddress
            );

            if (element == targetValue) {
                return (center, true);
            } else if (element < targetValue) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return (lower, true);
    }

    function _callGetLength(bytes memory lengthFuncPacked, address caller)
        internal
        view
        returns (uint32)
    {
        (bool success, bytes memory result) = caller.staticcall(
            lengthFuncPacked
        );
        if (success) {
            return abi.decode(result, (uint32));
        } else {
            revert("call failed: getLength");
        }
    }

    function _callGetElementByIdx(
        bytes memory elementFuncPacked,
        uint32 index,
        address caller
    ) internal view returns (uint256) {
        (bool success, bytes memory result) = caller.staticcall(
            abi.encodePacked(elementFuncPacked, uint256(index))
        );
        if (success) {
            return abi.decode(result, (uint256));
        } else {
            revert("call failed: get Element");
        }
    }

    /// @dev curry of uint256s
    function curryUint(bytes4 funcSig, uint256[] memory args)
        public
        pure
        returns (bytes memory)
    {
        bytes memory packed;
        for (uint256 i = 0; i < args.length; i++) {
            if (i == 0) {
                packed = abi.encodePacked(args[i]);
            } else {
                packed = abi.encodePacked(packed, args[i]);
            }
        }
        return abi.encodePacked(funcSig, packed);
    }

    function bytesToAddress(bytes calldata data)
        external
        pure
        returns (address addr)
    {
        bytes memory b = data;
        assembly {
            addr := mload(add(b, 20))
        }
    }

    function bytesToUint256(bytes calldata data)
        external
        pure
        returns (uint256 num)
    {
        bytes memory b = data;
        assembly {
            num := mload(add(b, 0x20))
        }
    }

    function bytesToUint32(bytes calldata data)
        external
        pure
        returns (uint32 num)
    {
        bytes memory b = data;
        assembly {
            num := mload(add(b, 0x20))
        }
    }

    function bytesToUint8(bytes calldata data)
        external
        pure
        returns (uint8 num)
    {
        bytes memory b = data;
        assembly {
            num := mload(add(b, 0x20))
        }
    }

    function bytesToBool(bytes calldata data) external pure returns (bool bin) {
        bytes memory b = data;
        assembly {
            bin := mload(add(b, 0x20))
        }
    }

    function bytesToUint(bytes memory b) internal pure returns (uint256) {
        uint256 number;
        for (uint256 i = 0; i < b.length; i++) {
            number =
                number +
                uint256(uint8(b[i])) *
                (2**(8 * (b.length - (i + 1))));
        }
        return number;
    }
}
