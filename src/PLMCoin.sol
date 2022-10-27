// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMCoin is ERC20, IPLMCoin {
    address public treasury;
    event mintDebug(uint256 amount, address user);

    mapping(address => uint256) subscExpiredPoint;

    constructor(uint256 _initialMint) ERC20("polylem", "PLM") {
        treasury = msg.sender;
        _mint(treasury, _initialMint);
    }

    function getSubscExpiredPoint(address account)
        external
        view
        returns (uint256)
    {
        return subscExpiredPoint[account];
    }

    function banAccount(address account, uint256 banPeriod) external {
        subscExpiredPoint[account] -= banPeriod;
    }

    // TODO: for debug
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
        emit mintDebug(amount, msg.sender);
    }
}
