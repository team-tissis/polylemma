// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "../interfaces/IPLMToken.sol";
import {IPLMCoin} from "../interfaces/IPLMCoin.sol";
import {IPLMGacha} from "../interfaces/IPLMGacha.sol";

contract PLMGacha is IPLMGacha, ReentrancyGuard {
    uint256 constant GACHA_FEE = 5;

    uint256 constant GACHA_SEQ_LIMIT = 10;

    /// @notice interface to the token contract of polylemma
    IPLMToken token;

    /// @notice interface to the coin contract of polylemma.
    IPLMCoin coin;

    /////////////////////////
    ///  GACHA FUNCTIONS  ///
    /////////////////////////

    /// @notice function to execute gacha multiple times.
    /// @dev    first owner of all PLMToken is this contract because token.mint() is called by this contract.
    ///         1. pay PLMCoin by the sender
    ///         2. mint PLMToken by this contract
    ///         2. transfer minted token from this contract to the sender
    function gacha(
        bytes32[] calldata names,
        uint256 num
    ) external nonReentrant {
        require(
            num >= 1 && num <= GACHA_SEQ_LIMIT,
            "exceeds the num. limit of simultaneous gacha."
        );
        coin.transferFrom(msg.sender, address(this), GACHA_FEE * num);
        for (uint8 idx = 0; idx < num; idx++) {
            uint256 tokenId = token.mint(names[idx]);
            token.transferFrom(address(this), msg.sender, tokenId);
            emit CharacterReceivedByUser(
                msg.sender,
                tokenId,
                token.getCurrentCharacterInfo(tokenId)
            );
        }
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getGachaFee() external pure returns (uint256) {
        return GACHA_FEE;
    }
}
