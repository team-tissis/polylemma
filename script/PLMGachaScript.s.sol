// depoly script for polylemma local node test
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {PLMCoin} from "src/PLMCoin.sol";
import {PLMToken} from "src/PLMToken.sol";
import {PLMDealer} from "src/PLMDealer.sol";

import {IPLMToken} from "../src/interfaces/IPLMToken.sol";
import {IPLMCoin} from "../src/interfaces/IPLMCoin.sol";
import {IPLMDealer} from "../src/interfaces/IPLMDealer.sol";

contract PolylemmagachaScript is Script {
    PLMToken tokenContract;
    PLMCoin coinContract;
    PLMDealer dealerContract;

    IPLMToken token;
    IPLMCoin coin;
    IPLMDealer dealer;

    IPLMToken.CharacterInfo characterInfo;

    uint256 constant tokenMaxSupply = 1000;
    uint256 constant initialMintCoin = 1000000;
    address tmp = address(999);

    // game admin address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        coinContract = new PLMCoin(tmp);
        coin = IPLMCoin(address(coinContract));

        tokenContract = new PLMToken(tmp, coin, tokenMaxSupply);
        token = IPLMToken(address(tokenContract));

        dealer = new PLMDealer(token, coin);

        coin.setDealer(address(dealer));
        token.setDealer(address(dealer));

        // initialMint for Dealer
        dealer.mintAdditionalCoin(initialMintCoin);

        vm.stopBroadcast();
    }
}
