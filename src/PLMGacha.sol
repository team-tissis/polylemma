// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMGacha} from "./interfaces/IPLMGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PLMGacha is IPLMGacha, ReentrancyGuard {
    IPLMToken public token;
    IPLMCoin public coin;

    address dealer;
    address treasury;

    uint256 gachaPayment;

    modifier onlyDealer() {
        require(msg.sender == dealer, "this address is not game master.");
        _;
    }

    constructor(
        IPLMToken _token,
        IPLMCoin _coin,
        address _treasury,
        uint256 _gachaPayment
    ) {
        token = _token;
        coin = _coin;
        treasury = _treasury;
        gachaPayment = _gachaPayment;
    }

    function gacha() external nonReentrant returns (uint256) {
        require(
            coin.allowance(msg.sender, address(this)) >= gachaPayment,
            "coin allowance insufficient /gacha"
        );
        require(
            coin.balanceOf(msg.sender) >= gachaPayment,
            "not sufficient balance /gacha"
        );
        // TODO: require battle proposal
        return _gacha();
    }

    function _gacha() internal returns (uint256) {
        try token.mint() returns (uint256 tokenId) {
            try coin.transferFrom(msg.sender, treasury, gachaPayment) {
                token.transferFrom(address(this), msg.sender, tokenId);
                // TODO: should also emit characterinfo
                emit CharacterRecievedByUser(
                    tokenId,
                    token.getCharacterInfo(tokenId)
                );
                return tokenId;
            } catch Error(string memory) {
                token.burn(tokenId);
                // TODO:emit gacha payment failed
                return 0;
            }
        } catch Error(string memory) {
            return 0;
        }
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyDealer {
        gachaPayment = _newGachaPayment;
    }
}
