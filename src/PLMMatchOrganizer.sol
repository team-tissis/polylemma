// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PLMBattleField} from "./subcontracts/PLMBattleField.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMMatchOrganizer} from "./interfaces/IPLMMatchOrganizer.sol";

contract PLMMatchOrganizer is PLMBattleField, IPLMMatchOrganizer {
    constructor(IPLMDealer _dealer, IPLMToken _token) {
        dealer = _dealer;
        token = _token;
    }
    // TODO
}
