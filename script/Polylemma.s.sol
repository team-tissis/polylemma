// depoly script for polylemma local node test
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMToken} from "src/PLMToken.sol";
import {PLMData} from "src/PLMData.sol";
import {PLMDealer} from "src/PLMDealer.sol";
import {PLMMatchOrganizer} from "src/PLMMatchOrganizer.sol";
import {PLMBattleField} from "src/PLMBattleField.sol";
import {PLMBattleManager} from "../src/PLMBattleManager.sol";
import {PLMBattleStorage} from "../src/PLMBattleStorage.sol";
import {PLMTypesV1} from "src/data-contracts/PLMTypesV1.sol";
import {PLMLevelsV1} from "src/data-contracts/PLMLevelsV1.sol";

import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMBattleManager} from "../src/interfaces/IPLMBattleManager.sol";
import {IPLMBattleStorage} from "../src/interfaces/IPLMBattleStorage.sol";
import {IPLMBattleField} from "src/interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "src/interfaces/IPLMMatchOrganizer.sol";
import {IPLMTypes} from "src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "src/interfaces/IPLMLevels.sol";

contract PolylemmaScript is Script {
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMData dataContract;
    PLMDealer dealerContract;
    PLMMatchOrganizer matchOrganizer;
    PLMBattleField battleField;
    PLMTypesV1 typesContract;
    PLMLevelsV1 levelsContract;
    IPLMBattleStorage strg;
    IPLMBattleManager manager;

    PLMBattleStorage strgContract;
    PLMBattleManager managerContract;
    IPLMToken token;
    IPLMCoin coin;
    IPLMDealer dealer;
    IPLMData data;
    IPLMTypes types;
    IPLMLevels levels;

    uint256 constant tokenMaxSupply = 1000;

    // uint256 constant initialMintCoin = 1000000;

    // game admin address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));

        levelsContract = new PLMLevelsV1();
        levels = IPLMLevels(levelsContract);

        typesContract = new PLMTypesV1();
        types = IPLMTypes(typesContract);

        dataContract = new PLMData(types, levels);
        data = IPLMData(address(dataContract));

        tokenContract = new PLMToken(coin, data, tokenMaxSupply);
        token = IPLMToken(address(tokenContract));

        strgContract = new PLMBattleStorage();
        strg = IPLMBattleStorage(address(strgContract));
        managerContract = new PLMBattleManager(strg);
        manager = IPLMBattleManager(address(managerContract));
        dealer = new PLMDealer(token, coin);
        matchOrganizer = new PLMMatchOrganizer(dealer, token);
        battleField = new PLMBattleField(dealer, token, manager);

        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));
        dealer.setMatchOrganizer(address(matchOrganizer));
        dealer.setBattleField(address(battleField));
        strg.setBattleManager(address(managerContract));

        matchOrganizer.setPLMBattleField(address(battleField));
        battleField.setPLMMatchOrganizer(address(matchOrganizer));

        // initialMint for Dealer
        // dealer.mintAdditionalCoin(initialMintCoin);

        vm.stopBroadcast();
    }
}
