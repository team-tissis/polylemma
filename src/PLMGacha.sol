// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMGacha} from "./interfaces/IPLMGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PLMGacha is IPLMGacha, ReentrancyGuard {
    IPLMToken public PLMToken;
    IPLMCoin public PLMCoin;

    address dealer;

    uint256 gachaPayment;

    modifier onlyDealer() {
        require(msg.sender == dealer, "this address is not game master.");
        _;
    }

    constructor(IPLMToken _PLMToken, IPLMCoin _PLMCoin, uint256 _gachaPayment) {
        PLMToken = _PLMToken;
        PLMCoin = _PLMCoin;
        gachaPayment = _gachaPayment;
    }

    function gacha() external nonReentrant returns (uint256) {
        // require(PLMCoin.balanceOf(msg.sender)<);
        try PLMToken.mint() returns (uint256 tokenId) {
            emit CharacterRecievedByUser(tokenId);
            return tokenId;
        } catch Error(string memory) {
            return 0;
        }
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyDealer {
        gachaPayment = _newGachaPayment;
    }
}
