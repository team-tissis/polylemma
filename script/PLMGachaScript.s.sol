pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMData} from "src/PLMData.sol";
import {PLMGacha} from "src/PLMGacha.sol";
import {PLMSeeder} from "src/PLMSeeder.sol";
import {PLMStamina} from "src/PLMStamina.sol";
import {PLMToken} from "src/PLMToken.sol";

import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";

contract PolylemmagachaScript is Script {
    PLMData dataContract;
    PLMSeeder seederContract;
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMGacha gacha;

    IPLMData data;
    IPLMSeeder seeder;
    IPLMToken token;
    IPLMCoin coin;

    IPLMToken.CharacterInfo characterInfo;

    // game admin address
    address tmpMinter = address(1);

    uint256 subscFee = 10;
    uint256 subscDuration = 600000;

    uint256 maxSupplyChar = 10000;
    uint256 initialMintCoin = 100000000;
    uint256 gachaPayment = 5;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        dataContract = new PLMData();
        seederContract = new PLMSeeder();

        seeder = IPLMSeeder(address(seederContract));
        data = IPLMData(address(dataContract));

        coinContract = new PLMCoin(initialMintCoin);
        coin = IPLMCoin(address(coinContract));

        tokenContract = new PLMToken(
            tmpMinter,
            seeder,
            data,
            coin,
            maxSupplyChar
        );
        token = IPLMToken(address(tokenContract));

        gacha = new PLMGacha(token, coin, gachaPayment);
        token.setMinter(address(gacha));
        vm.stopBroadcast();
    }
}
