// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";

contract PLMCoin is ERC20, IPLMCoin {
    address polylemmer;
    address public dealer;

    constructor(address _dealer) ERC20("polylemma", "PLM") {
        polylemmer = msg.sender;
        dealer = _dealer;
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "sender is not dealer.");
        _;
    }

    modifier onlyPolylemmer() {
        require(msg.sender == polylemmer, "sender is not deployer.");
        _;
    }

    function mint(uint256 amount) public onlyDealer {
        _mint(msg.sender, amount);
    }

    function setDealer(address _dealer) external onlyPolylemmer {
        dealer = _dealer;
    }
}
