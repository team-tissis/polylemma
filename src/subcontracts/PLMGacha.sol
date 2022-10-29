// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import {IPLMToken} from "../interfaces/IPLMToken.sol";
import {IPLMCoin} from "../interfaces/IPLMCoin.sol";
import {IPLMGacha} from "../interfaces/IPLMGacha.sol";

contract PLMGacha is IPLMGacha, ReentrancyGuard {
    IPLMToken public token;
    IPLMCoin public coin;

    uint256 constant GACHA_FEE = 5;

    function gacha(bytes20 name) public nonReentrant {
        require(
            coin.allowance(msg.sender, address(this)) >= GACHA_FEE,
            "coin allowance insufficient /gacha"
        );
        require(
            coin.balanceOf(msg.sender) >= GACHA_FEE,
            "not sufficient balance /gacha"
        );
        try token.mint(name) returns (uint256 tokenId) {
            try coin.transferFrom(msg.sender, address(this), GACHA_FEE) {
                token.transferFrom(address(this), msg.sender, tokenId);
                emit CharacterReceivedByUser(
                    msg.sender,
                    tokenId,
                    token.getCharacterInfo(tokenId)
                );
            } catch Error(string memory reason) {
                token.burn(tokenId);
                // TODO:emit gacha payment failed
                revert ErrorWithLog(reason);
            }
        } catch Error(string memory reason) {
            revert ErrorWithLog(reason);
        }
    }

    function getGachaFee() public pure returns (uint256) {
        return GACHA_FEE;
    }
}
