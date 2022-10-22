// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPlmToken} from "./interfaces/IPlmToken.sol";
import {IPlmCoin} from "./interfaces/IPlmCoin.sol";
import {IPlmGacha} from "./interfaces/IPlmGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract PlmGacha is IPlmGacha, ReentrancyGuard {
    IPlmToken public plmToken;
    IPlmCoin public plmCoin;

    address dealer;

    uint256 gachaPayment;

    modifier onlyDealer() {
        require(msg.sender == dealer, "this address is not game master.");
        _;
    }

    constructor(
        IPlmToken _plmToken,
        IPlmCoin _plmCoin,
        uint256 _gachaPayment
    ) {
        plmToken = _plmToken;
        plmCoin = _plmCoin;
        gachaPayment = _gachaPayment;
    }

    function gacha() external nonReentrant {
        // require(plmCoin.balanceOf(msg.sender)<);
        try plmToken.mint() returns (uint256 tokenId) {
            emit CharacterRecievedByUser(tokenId);
        } catch Error(string memory) {}
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyDealer {
        gachaPayment = _newGachaPayment;
    }
}
