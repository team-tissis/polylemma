// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMCoin is ERC20, IPLMCoin {
    address public treasury;

    constructor(address _treasury, uint256 _initialMint) ERC20("polylem", "PLM") {
        treasury = _treasury;
        _mint(_treasury, _initialMint);
    }
}
