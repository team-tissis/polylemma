// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Math} from "openzeppelin-contracts/utils/math/math.sol";
import {SafeMath} from "openzeppelin-contracts/utils/math/SafeMath.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMCoin is ERC20, IPLMCoin {
    using Math for uint256;
    using SafeMath for uint256;

    IPLMData data;

    address dealer;
    address public treasury;
    event mintDebug(uint256 amount, address indexed user);
    uint256 maticAmount;
    uint256 subscFee;
    uint256 subscDuration;

    mapping(address => uint256) subscExpiredPoint;

    constructor(
        IPLMData _data,
        address _treasury,
        uint256 _subscFee,
        uint256 _subscDuration
    ) ERC20("polylem", "PLM") {
        data = _data;
        dealer = msg.sender;
        treasury = _treasury;
        subscFee = _subscFee;
        subscDuration = _subscDuration;
    }

    modifier onlyTreasury() {
        require(msg.sender == treasury, "sender is not treasury.");
        _;
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "sender is not dealer.");
        _;
    }

    function getSubscExpiredPoint(address account)
        external
        view
        returns (uint256)
    {
        return subscExpiredPoint[account];
    }

    function subscIsExpired(address account) external view returns (bool) {
        return block.number > subscExpiredPoint[account];
    }

    function updateSubsc() external returns (uint256) {
        require(balanceOf(msg.sender) >= subscFee);
        // TODO: safe Transfer
        transfer(treasury, subscFee);
        _updateSubsc(msg.sender);
        return subscExpiredPoint[msg.sender];
    }

    function _updateSubsc(address account) internal {
        subscExpiredPoint[account] =
            subscExpiredPoint[account].max(block.number) +
            subscDuration;
    }

    function banAccount(address account, uint256 banPeriod) external {
        subscExpiredPoint[account] -= banPeriod;
    }

    function getSubscFee() public view returns (uint256) {
        return subscFee;
    }

    function getSubscDuration() public view returns (uint256) {
        return subscDuration;
    }

    // TODO: for debug
    // TODO: user indexed event
    function mint(uint256 amount) public onlyTreasury {
        _mint(msg.sender, amount);
    }

    function setTreasury(address _treasury) external onlyDealer {
        treasury = _treasury;
    }
}
