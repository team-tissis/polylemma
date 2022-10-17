// depoly script for polylemma local node test
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMExchange} from "src/PLMExchange.sol";
import {PLMData} from "src/PLMData.sol";
import {PLMGacha} from "src/PLMGacha.sol";
import {PLMSeeder} from "src/PLMSeeder.sol";
import {PLMStamina} from "src/PLMStamina.sol";
import {PLMToken} from "src/PLMToken.sol";

import {IPLMData} from "../src/interfaces/IPLMData.sol";
import {IPLMSeeder} from "../src/interfaces/IPLMSeeder.sol";
import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMExchange} from "../src/interfaces/IPLMExchange.sol";

contract PolylemmagachaScript is Script {
    PLMData dataContract;
    PLMSeeder seederContract;
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMExchange exContract;
    PLMGacha gacha;

    IPLMData data;
    IPLMSeeder seeder;
    IPLMToken token;
    IPLMCoin coin;
    IPLMExchange ex;

    IPLMToken.CharacterInfo characterInfo;

    // game admin address
    address tmpMinter = address(9);
    address tmpTreasury = address(99);

    address treasury;
    address minter;

    uint256 subscFee = 10;
    uint256 subscDuration = 600000;

    uint256 maxSupplyChar = 10000;
    uint256 initialMintCoin = 100000000;
    uint256 gachaPayment = 5;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        // deploy data storage
        dataContract = new PLMData();
        data = IPLMData(address(dataContract));

        // deploy seeder
        seederContract = new PLMSeeder();
        seeder = IPLMSeeder(address(seederContract));

        // deploy ERC20, subsc contract
        coinContract = new PLMCoin(data, tmpTreasury, subscFee, subscDuration);
        coin = IPLMCoin(address(coinContract));

        // deploy exchanger of ERC20 contract
        exContract = new PLMExchange(data, coin);
        ex = IPLMExchange(address(exContract));
        treasury = address(exContract);

        // set coin treasury
        coin.setTreasury(treasury);
        // initialMint for Treasury
        ex.mintForTreasury(initialMintCoin);

        // deploy ERC721 contract
        tokenContract = new PLMToken(
            tmpMinter,
            seeder,
            data,
            coin,
            maxSupplyChar
        );
        token = IPLMToken(address(tokenContract));

        gacha = new PLMGacha(token, coin, gachaPayment);
        minter = address(gacha);
        token.setMinter(address(gacha));

        vm.stopBroadcast();
    }
}
