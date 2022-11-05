// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";

contract PLMCoin is ERC20, IPLMCoin {
    address polylemmer;
    address public dealer;
    bool DealerIsSet = false;

    constructor() ERC20("polylemma", "PLM") {
        polylemmer = msg.sender;
    }

    modifier onlyDealer() {
        require(DealerIsSet, "dealer has not been set.");
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
        DealerIsSet = true;
    }

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////
    // FIXME: remove this function after demo.
    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
