// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Math} from "openzeppelin-contracts/utils/math/math.sol";

import {PLMGacha} from "./subcontracts/PLMGacha.sol";

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";

contract PLMDealer is PLMGacha, IPLMDealer {
    using Math for uint256;

    address dealer;
    address polylemmer;
    address matchOrganizer;
    bool matchOrganizerIsSet = false;

    /// @notice subscription Fee (PLMCoin) for one period.
    uint256 constant SUBSC_FEE_PER_UNIT_PERIOD = 10;

    /// @notice block number of subscription period unit (30 days).
    uint256 constant SUBSC_UNIT_PERIOD_BLOCK_NUM = 1296000;

    /// @notice The amount of stamina recovery per one block.
    uint8 constant STAMINA_RESTORE_SPEED = 5;

    /// @notice The maximum value of stamina.
    uint8 constant STAMINA_MAX = 100;

    //// @notice the fee to restore stamina (unit: PLM)
    uint8 constant RESTORE_STAMINA_FEE = 1;

    /// @notice The amount of stamina consumed when playing battle with other players.
    uint8 constant STAMINA_PER_BATTLE = 10;

    /// @notice Mapping from each account to one's subscription expired block number.
    mapping(address => uint256) subscExpiredBlock;

    /// @notice The block number when the stamina is zero for each player.
    mapping(address => uint256) staminaFromBlock;

    constructor(IPLMToken _token, IPLMCoin _coin) {
        dealer = address(this);
        polylemmer = msg.sender;
        token = _token;
        coin = _coin;
    }

    modifier onlyPolylemmer() {
        require(msg.sender == polylemmer, "sender is not polylemmer");
        _;
    }

    modifier onlyMatchOrganizer() {
        require(matchOrganizerIsSet, "matchOrganizer has not been set.");
        require(msg.sender == matchOrganizer, "sender is not matchOrganizer");
        _;
    }

    ////////////////////////////////
    /// FUNCTIONS ABOUT FINANCES ///
    ////////////////////////////////

    function balanceOfMatic() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw(uint256 amount) public onlyPolylemmer {
        // Total amount of MATIC this contract owns.
        uint256 totalAmount = address(this).balance;

        // Check that withdrawal is possible.
        require(amount <= totalAmount, "cannot withdraw over total balance.");

        // Execute withdrawal.
        (bool success, ) = payable(dealer).call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    /// @notice This function is used when the amount of PLMCoin the dealer has is insufficient.
    function mintAdditionalCoin(uint256 amount) public onlyPolylemmer {
        coin.mint(amount);
    }

    ///////////////////////////////
    /// FUNCTIONS ABOUT STAMINA ///
    ///////////////////////////////
    function initializeStamina(address player) internal {
        _restoreStamina(player);
    }

    // TODO: if block number is smaller than STAMINA_MAX, it cannot work.
    function getCurrentStamina(address player) public view returns (uint8) {
        if (block.number < STAMINA_MAX) {
            // TODO
            return STAMINA_MAX;
        } else if (block.number > staminaFromBlock[player]) {
            return
                uint8(
                    ((block.number - staminaFromBlock[player]) *
                        STAMINA_RESTORE_SPEED).min(STAMINA_MAX)
                );
        } else {
            // TODO
            return 0;
        }
    }

    function getStaminaMax() public pure returns (uint8) {
        return STAMINA_MAX;
    }

    function getStaminaPerBattle() public pure returns (uint8) {
        return STAMINA_PER_BATTLE;
    }

    function getRestoreStaminaFee() public pure returns (uint8) {
        return RESTORE_STAMINA_FEE;
    }

    /// @notice need approvement of coin to dealer
    function restoreFullStamina(address player) public nonReentrant {
        require(
            coin.balanceOf(msg.sender) >= 1,
            "player does not have enough coin"
        );
        require(
            getCurrentStamina(player) < STAMINA_MAX,
            "player's stamina is full"
        );
        coin.transferFrom(msg.sender, dealer, RESTORE_STAMINA_FEE);
        _restoreStamina(player);
    }

    function _restoreStamina(address player) internal {
        uint256 restAmount = uint256(STAMINA_MAX / STAMINA_RESTORE_SPEED);

        // Deal with underflow.
        staminaFromBlock[player] = block.number >= restAmount
            ? block.number - restAmount
            : 0;
    }

    function consumeStaminaForBattle(address player) public onlyMatchOrganizer {
        require(
            block.number >=
                staminaFromBlock[player] +
                    STAMINA_PER_BATTLE /
                    STAMINA_RESTORE_SPEED,
            "sender does not have enough stamina"
        );
        staminaFromBlock[player] += STAMINA_PER_BATTLE / STAMINA_RESTORE_SPEED;
    }

    ////////////////////////////////////
    /// FUNCTIONS ABOUT SUBSCRIPTION ///
    ////////////////////////////////////

    /// @notice Function to get the subscription expired block number of the account.
    function getSubscExpiredBlock(address account)
        public
        view
        returns (uint256)
    {
        return subscExpiredBlock[account];
    }

    /// @notice Function to get the number blocks remained until subscription expired block.
    function getSubscRemainingBlockNum(address account)
        public
        view
        returns (uint256)
    {
        uint256 remainingBlockNum = block.number <=
            getSubscExpiredBlock(account)
            ? getSubscExpiredBlock(account) - block.number
            : 0;
        return remainingBlockNum;
    }

    /// @notice Function to return whether the account's subscription is expired or not.
    function subscIsExpired(address account) external view returns (bool) {
        return block.number > getSubscExpiredBlock(account);
    }

    /// @notice Function to extend subscription period. Need approvement of coin to dealer
    function extendSubscPeriod() external {
        // Check the user owns enough PLMCoin to extend one's subscription period.
        require(coin.balanceOf(msg.sender) >= SUBSC_FEE_PER_UNIT_PERIOD);

        uint256 currentExpiredBlock = getSubscExpiredBlock(msg.sender);

        // TODO: modify here from transfer to safeTransfer.
        // Transfer PLMCoin from user to dealer as subscription fee.
        coin.transferFrom(msg.sender, dealer, SUBSC_FEE_PER_UNIT_PERIOD);

        // Update subscription period.
        _extendSubscPeriod(msg.sender);

        emit SubscExtended(
            msg.sender,
            currentExpiredBlock,
            getSubscExpiredBlock(msg.sender)
        );
    }

    // TODO: requireがいる？
    /// @notice Function to ban account for the period designated by banPeriod.
    /// @dev This function is called from BattleField contract when cheating detected.
    function banAccount(address account, uint256 banPeriod) external {
        uint256 currentExpiredBlock = getSubscExpiredBlock(account);

        // Deal with underflow.
        subscExpiredBlock[account] = subscExpiredBlock[account] >= banPeriod
            ? subscExpiredBlock[account] - banPeriod
            : 0;

        emit SubscShortened(
            msg.sender,
            currentExpiredBlock,
            getSubscExpiredBlock(account)
        );
    }

    function getSubscFeePerUnitPeriod() public pure returns (uint256) {
        return SUBSC_FEE_PER_UNIT_PERIOD;
    }

    function getSubscUnitPeriodBlockNum() public pure returns (uint256) {
        return SUBSC_UNIT_PERIOD_BLOCK_NUM;
    }

    function _extendSubscPeriod(address account) internal {
        subscExpiredBlock[account] =
            getSubscExpiredBlock(account).max(block.number) +
            SUBSC_UNIT_PERIOD_BLOCK_NUM;
    }

    //////////////////////////////////
    /// FUNCTIONS ABOUT CHARGEMENT ///
    //////////////////////////////////

    /// @notice Function used by game users to charge MATIC to get PLMCoin.
    /// @dev The price of PLMCoin is pegged to MATIC as 1:1.
    function charge() public payable {
        // This is the first function users call when they join this game.
        //  functions to initialize smothing are called here.
        if (staminaFromBlock[msg.sender] == 0) {
            initializeStamina(msg.sender);
        }

        // MINT PLMCoin whose amount is equal to the amount of MATIC the user charged.
        uint256 mintValue = msg.value / 1e18;
        uint256 deposit = msg.value % 1e18;
        coin.mint(mintValue);
        (bool success, ) = payable(msg.sender).call{value: deposit}("");
        // Distribute minted PLMCoins to the charger and the PLMCoin pool (dealer).
        _transferPLMCoinWithPooling(msg.sender, mintValue);
        require(success, "Failed to send deposit Ether");
    }

    /// @notice Function to transfer minted PLMCoin to the charger and PLMCoin pool.
    /// @dev The distribution is determined in a progressive taxation manner.
    /// @param account: game player's account who charged MATIC to get PLMCoin.
    /// @param totalAmount: sum of the amount of PLMCoin distributed to the player and PLMCoin pool.
    function _transferPLMCoinWithPooling(address account, uint256 totalAmount)
        internal
    {
        // Calcuate how much PLMCoin are stored in the PLMCoin pool.
        uint256 poolingAmount = _calcPoolingAmount(totalAmount);

        // Transfer rest of the minted PLMCoin to the account who charged.
        coin.transfer(account, totalAmount - poolingAmount);
        emit AccountCharged(account, totalAmount, poolingAmount);
    }

    /// @notice Function to calculate the pooling amount.
    function _calcPoolingAmount(uint256 totalAmount)
        internal
        view
        returns (uint256)
    {
        // get the pooling percentage from PLMData contract.
        uint256 poolingPercentage = token.getPoolingPercentage(totalAmount);
        return (totalAmount * poolingPercentage) / 100;
    }

    //////////////////////////////////////////////////////////////////////////////
    /// FUNCTIONS USED BY BATTLE FIELD CONTRACT TO CALCULATE REWARD FOR WINNER ///
    //////////////////////////////////////////////////////////////////////////////

    function payReward(address winner, uint256 amount) external {
        _payReward(winner, amount);
    }

    function _payReward(address winner, uint256 amount) internal {
        coin.transfer(winner, amount);
    }

    ////////////////////////////
    /// FUNCTIONS FOR CONFIG ///
    ////////////////////////////
    function setMatchOrganizer(address _matchOrganizer)
        external
        onlyPolylemmer
    {
        matchOrganizerIsSet = true;
        matchOrganizer = _matchOrganizer;
    }
}
