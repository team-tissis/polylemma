// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";

contract PLMCoin is ERC20, IPLMCoin {
    /// @notice admin's address
    address polylemmers;

    /// @notice contract address of the dealer of polylemma.
    address public dealer;

    constructor() ERC20("polylemma", "PLM") {
        polylemmers = msg.sender;
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "sender != dealer");
        _;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != deployer");
        _;
    }

    /////////////////////////
    ///  COIN FUNCTIONS   ///
    /////////////////////////

    /// @notice mint by dealer address, function called by only dealer contract
    function mint(uint256 amount) external onlyDealer {
        _mint(msg.sender, amount);
    }

    /////////////////////////
    ///      SETTERS      ///
    /////////////////////////

    /// @notice set dealer contract address, function called by only Polylemmers EOA
    /// @dev    "dealer" is a contract that controlls all features including coin dealing in the game.
    ///         This function must be called when initializing contracts by the deployer manually.
    ///         ("polylemmers" is contract deployer's address.)
    function setDealer(address _dealer) external onlyPolylemmers {
        dealer = _dealer;
    }

    //////////////////////////
    /// FUNCTIONS FOR DEMO ///
    //////////////////////////

    // FIXME: remove this function after demo.
    /// @notice mint coins without payment. for demo and test
    function faucet(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
