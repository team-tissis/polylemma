// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {PLMDealer} from "../../src/PLMDealer.sol";
import {PLMCoin} from "../../src/PLMCoin.sol";
import {PLMToken} from "../../src/PLMToken.sol";
import {PLMMatchOrganizer} from "../../src/PLMMatchOrganizer.sol";
import {PLMBattleField} from "../../src/PLMBattleField.sol";
import {PLMData} from "../../src/PLMData.sol";
import {PLMTypesV1} from "../../src/data-contracts/PLMTypesV1.sol";
import {PLMLevelsV1} from "../../src/data-contracts/PLMLevelsV1.sol";

import {IPLMDealer} from "../../src/interfaces/IPLMDealer.sol";
import {IPLMCoin} from "../../src/interfaces/IPLMCoin.sol";
import {IPLMToken} from "../../src/interfaces/IPLMToken.sol";
import {IPLMMatchOrganizer} from "../../src/interfaces/IPLMMatchOrganizer.sol";
import {IPLMBattleField} from "../../src/interfaces/IPLMBattleField.sol";
import {IPLMData} from "../../src/interfaces/IPLMData.sol";
import {IPLMTypes} from "../../src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "../../src/interfaces/IPLMLevels.sol";

contract TestUtils is Test {
    /// @dev all contracts
    PLMDealer dealerContract;
    PLMCoin coinContract;
    PLMToken tokenContract;
    PLMMatchOrganizer moContract;
    PLMBattleField bfContract;
    PLMData dataContract;
    PLMTypesV1 typesContract;
    PLMLevelsV1 levelsContract;

    IPLMDealer dealer;
    IPLMCoin coin;
    IPLMToken token;
    IPLMMatchOrganizer mo;
    IPLMBattleField bf;
    IPLMData data;
    IPLMTypes types;
    IPLMLevels levels;

    ///@dev deployer address
    address polylemmer = address(1);

    ///@dev to manage blockNumber by vm.roll()
    uint256 currentBlock = 0;

    ///@dev token max supply (constructor param.)
    uint256 max_supply = 100000;

    function baseSetUp() internal {
        // send transaction by deployer
        vm.startPrank(polylemmer);

        // deploy contracts
        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));

        typesContract = new PLMTypesV1();
        types = IPLMTypes(address(typesContract));

        levelsContract = new PLMLevelsV1();
        levels = IPLMLevels(address(levelsContract));

        dataContract = new PLMData(types, levels);
        data = IPLMData(address(dataContract));

        tokenContract = new PLMToken(coin, data, max_supply);
        token = IPLMToken(address(tokenContract));

        dealerContract = new PLMDealer(token, coin);
        dealer = IPLMDealer(address(dealerContract));

        moContract = new PLMMatchOrganizer(dealer, token);
        mo = IPLMMatchOrganizer(address(moContract));

        bfContract = new PLMBattleField(dealer, token);
        bf = IPLMBattleField(address(bfContract));

        // set dealer
        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));
        dealer.setMatchOrganizer(address(mo));
        dealer.setBattleField(address(bf));
        bf.setPLMMatchOrganizer(address(mo));
        mo.setPLMBattleField(address(bf));

        // set block number to be enough length to manage stamina
        currentBlock = dealerContract.getStaminaMax() * 300 + 1000;
        vm.roll(currentBlock);
        vm.stopPrank();
    }
}
