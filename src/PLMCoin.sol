// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMCoin is ERC20, IPLMCoin {
    address public treasury;
    event mintDebug(uint256 amount, address user);

    mapping(address => uint256) subscExpiredPoint;

    constructor(
        address _treasury,
        uint256 _initialMint,
        address _debugUser
    ) ERC20("polylem", "PLM") {
        treasury = _treasury;
        _mint(_treasury, _initialMint);
        _mint(_debugUser, _initialMint);
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
    function mint() public {
        _mint(msg.sender, 10000000);
        emit mintDebug(10000000, msg.sender);
    }
}
