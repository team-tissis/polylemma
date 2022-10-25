// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMGacha} from "./interfaces/IPLMGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PLMGacha is IPLMGacha, ReentrancyGuard {
    IPLMToken public token;
    IPLMCoin public coin;
    event Log(string message);
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
        uint256 _gachaPayment
    ) {
        treasury = msg.sender;
        token = _token;
        coin = _coin;
        gachaPayment = _gachaPayment;
    }

    function gacha() public nonReentrant {
        require(
            coin.allowance(msg.sender, address(this)) >= gachaPayment,
            "coin allowance insufficient /gacha"
        );
        require(
            coin.balanceOf(msg.sender) >= gachaPayment,
            "not sufficient balance /gacha"
        );
        uint256 tokenId = token.mint();
        coin.transferFrom(msg.sender, treasury, gachaPayment);
        // coin.transfer(msg.sender, gachaPayment);
        token.transferFrom(address(this), msg.sender, tokenId);
        // try token.mint() returns (uint256 tokenId) {
        //     try coin.transferFrom(msg.sender, treasury, gachaPayment) {
        //         token.transferFrom(address(this), msg.sender, tokenId);
        //         // TODO: should also emit characterinf
        //         emit CharacterRecievedByUser(
        //             tokenId,
        //             token.getCharacterInfo(tokenId)
        //         );
        //     } catch Error(string memory reason) {
        //         token.burn(tokenId);
        //         // TODO:emit gacha payment failed
        //         emit Log(reason);
        //     }
        // } catch Error(string memory reason) {
        //     emit Log(reason);
        // }
    }

    function getDealer() public view returns (address) {
        return dealer;
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyDealer {
        gachaPayment = _newGachaPayment;
    }

    function getGachaPayment() public view returns (uint256) {
        return gachaPayment;
    }
}
