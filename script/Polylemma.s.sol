// depoly script for polylemma local node test
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMToken} from "src/PLMToken.sol";
import {PLMData} from "src/PLMData.sol";
import {PLMDealer} from "src/PLMDealer.sol";
import {PLMMatchOrganizer} from "src/PLMMatchOrganizer.sol";
import {PLMBattleChoice} from "src/PLMBattleChoice.sol";
import {PLMBattlePlayerSeed} from "src/PLMBattlePlayerSeed.sol";
import {PLMBattleReporter} from "src/PLMBattleReporter.sol";
import {PLMBattleStarter} from "src/PLMBattleStarter.sol";
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
// import {IPLMBattleChoice} from "../src/interfaces/IPLMBattleChoice.sol";
// import {IPLMBattlePlayerSeed} from "../src/interfaces/IPLMBattlePlayerSeed.sol";
// import {IPLMBattleReporter} from "../src/interfaces/IPLMBattleReporter.sol";
// import {IPLMBattleStarter} from "../src/interfaces/IPLMBattleStarter.sol";
import {IPLMMatchOrganizer} from "../src/interfaces/IPLMMatchOrganizer.sol";
import {IPLMTypes} from "../src/interfaces/IPLMTypes.sol";
import {IPLMLevels} from "../src/interfaces/IPLMLevels.sol";

contract PolylemmaScript is Script {
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMData dataContract;
    PLMDealer dealerContract;
    PLMMatchOrganizer matchOrganizer;
    PLMBattleChoice battleChoice;
    PLMBattlePlayerSeed battlePlayerSeed;
    PLMBattleReporter battleReporter;
    PLMBattleStarter battleStarter;
    PLMTypesV1 typesContract;
    PLMLevelsV1 levelsContract;
    PLMBattleStorage strgContract;
    PLMBattleManager managerContract;


    IPLMBattleStorage strg;
    IPLMBattleManager manager;
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
        managerContract = new PLMBattleManager(token, strg);
        manager = IPLMBattleManager(address(managerContract));
        dealer = new PLMDealer(token, coin);
        matchOrganizer = new PLMMatchOrganizer(dealer, token);
        battleChoice = new PLMBattleChoice(dealer, token, manager);
        battlePlayerSeed = new PLMBattlePlayerSeed(dealer, token, manager);
        battleReporter = new PLMBattleReporter(dealer,token,manager);
        battleStarter = new PLMBattleStarter(dealer, token, manager);

        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));
        dealer.setMatchOrganizer(address(matchOrganizer));
        dealer.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));
        strg.setBattleManager(address(managerContract));
        manager.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));

        matchOrganizer.setPLMBattleContracts(address(battleChoice),address(battlePlayerSeed),address(battleReporter),address(battleStarter));
        battleChoice.setPLMMatchOrganizer(address(matchOrganizer));
        battlePlayerSeed.setPLMMatchOrganizer(address(matchOrganizer));
        battleReporter.setPLMMatchOrganizer(address(matchOrganizer));
        battleStarter.setPLMMatchOrganizer(address(matchOrganizer));

        // initialMint for Dealer
        // dealer.mintAdditionalCoin(initialMintCoin);

        vm.stopBroadcast();
    }
}
