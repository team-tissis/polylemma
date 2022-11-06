// depoly script for polylemma local node test
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMToken} from "src/PLMToken.sol";
import {PLMDealer} from "src/PLMDealer.sol";
import {PLMMatchOrganizer} from "src/PLMMatchOrganizer.sol";
import {PLMBattleField} from "src/subcontracts/PLMBattleField.sol";

import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";
import {IPLMBattleField} from "src/interfaces/IPLMBattleField.sol";
import {IPLMMatchOrganizer} from "src/interfaces/IPLMMatchOrganizer.sol";

contract PolylemmagachaScript is Script {
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMDealer dealerContract;
    PLMMatchOrganizer matchOrganizer;
    PLMBattleField battleField;

    IPLMToken token;
    IPLMCoin coin;
    IPLMDealer dealer;

    IPLMToken.CharacterInfo characterInfo;

    uint256 constant tokenMaxSupply = 1000;

    // uint256 constant initialMintCoin = 1000000;

    // game admin address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        coinContract = new PLMCoin();
        coin = IPLMCoin(address(coinContract));

        tokenContract = new PLMToken(coin, tokenMaxSupply);
        token = IPLMToken(address(tokenContract));

        dealer = new PLMDealer(token, coin);
        matchOrganizer = new PLMMatchOrganizer(dealer, token);
        battleField = new PLMBattleField(dealer, token);

        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));
        dealer.setMatchOrganizer(address(matchOrganizer));
        dealer.setBattleField(address(battleField));

        matchOrganizer.setIPLMBattleField(
            IPLMBattleField(address(battleField)),
            address(battleField)
        );
        battleField.setIPLMMatchOrganizer(
            IPLMMatchOrganizer(address(matchOrganizer)),
            address(matchOrganizer)
        );

        // initialMint for Dealer
        // dealer.mintAdditionalCoin(initialMintCoin);

        vm.stopBroadcast();
    }
}
