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
    address battleField;
    bool matchOrganizerIsSet = false;
    bool battleFieldIsSet = false;

    /// @notice subscription Fee (PLMCoin) for one period.
    uint256 constant SUBSC_FEE_PER_UNIT_PERIOD = 10;

    /// @notice block number of subscription period unit (30 days).
    uint256 constant SUBSC_UNIT_PERIOD_BLOCK_NUM = 1296000;

    /// @notice The number of blocks needed to recover unit stamina. (10 min).
    uint16 constant STAMINA_RESTORE_SPEED = 300;

    /// @notice The maximum value of stamina.
    uint8 constant STAMINA_MAX = 100;

    //// @notice the fee to restore stamina (unit: PLM)
    uint8 constant RESTORE_STAMINA_FEE = 5;

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
    modifier onlyBattleField() {
        require(battleFieldIsSet, "battleField has not been set.");
        require(msg.sender == battleField, "sender is not battleField");
        _;
    }

    ////////////////////////////////
    /// FUNCTIONS ABOUT FINANCES ///
    ////////////////////////////////

    /// @notice balance of sender MATIC
    function balanceOfMatic() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice withdraw MATIC send to this contract by player
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

    // TODO: if block number is smaller than STAMINA_MAX, it cannot work.
    /// @dev - This function calculate remained stamina ftom retained block numbers and stamina restoring speed.
    ///        This contract restores the block number at the time when each player's stamina was zero.
    ///      - When the current block number is less than max stamina point, this function return max stamina.
    function getCurrentStamina(address player) public view returns (uint8) {
        if (block.number < STAMINA_MAX) {
            // TODO:
            return STAMINA_MAX;
        } else if (block.number > staminaFromBlock[player]) {
            return
                uint8(
                    ((block.number - staminaFromBlock[player]) /
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

    /// @dev set stamina max value
    /// @dev Function called in charge() that is the first function users call when they join this game.
    function initializeStamina(address player) internal {
        _restoreStamina(player);
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

    /// @dev rewrite the retained block number that indicate the time when stamina is zero to shift it into the past
    function _restoreStamina(address player) internal {
        uint256 restAmount = uint256(STAMINA_MAX) *
            uint256(STAMINA_RESTORE_SPEED);

        // Deal with underflow.
        staminaFromBlock[player] = _safeSubUint256(block.number, restAmount);
    }

    /// @dev rewrite the retained block numbers that indicate the time when stamina is zero to shift it into the feature
    function consumeStaminaForBattle(address player) public onlyMatchOrganizer {
        require(
            block.number >=
                staminaFromBlock[player] +
                    STAMINA_PER_BATTLE *
                    STAMINA_RESTORE_SPEED,
            "sender does not have enough stamina"
        );
        // When "staminaFromBlock" remains at the initial value of "0", players start a battle without any stamina
        // consumption up to the time when the staminaFromBlock can express that stamina is consumed for one battle.
        if (staminaFromBlock[player] > 0) {
            staminaFromBlock[player] +=
                STAMINA_PER_BATTLE *
                STAMINA_RESTORE_SPEED;
        } else {
            staminaFromBlock[player] = _safeSubUint256(
                block.number,
                (STAMINA_MAX - STAMINA_PER_BATTLE) * STAMINA_RESTORE_SPEED
            );
        }
    }

    /// @notice function called when the battle did not end normally
    function refundStaminaForBattle(address player) public onlyBattleField {
        uint256 candidate1 = _safeSubUint256(
            block.number,
            STAMINA_MAX * STAMINA_RESTORE_SPEED
        );
        uint256 candidate2 = _safeSubUint256(
            staminaFromBlock[player],
            STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED
        );
        staminaFromBlock[player] = candidate1.max(candidate2);
    }

    // TODO: utils
    function _safeSubUint256(uint256 x, uint256 y)
        internal
        pure
        returns (uint256)
    {
        if (x >= y) {
            return x - y;
        } else {
            return 0;
        }
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

    // TODO: disable palyers from calling this function
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

    /// @notice Function to pay reward to battle winner address
    function payReward(address winner, uint256 amount) external {
        _payReward(winner, amount);
    }

    /// @dev reward is paid from dealer conteract address
    ///      coin.transfer is not called directly bacause the function needs to be called by payer of reward, dealer.
    function _payReward(address winner, uint256 amount) internal {
        coin.transfer(winner, amount);
    }

    ////////////////////////////
    ///         SETTER       ///
    ////////////////////////////

    /// @notice set match organizer contract address, function called by only Polylemmer EOA
    /// @dev   This function must be called when initializing contracts by the deployer manually. ("polylemmer" is contract deployer's address.)
    ///        "matchOrganizer" address is stored in this contract to make some functions able to be called from only matchOrganizer.
    function setMatchOrganizer(address _matchOrganizer)
        external
        onlyPolylemmer
    {
        matchOrganizerIsSet = true;
        matchOrganizer = _matchOrganizer;
    }

    /// @notice set battle field contract address, function called by only Polylemmer EOA
    /// @dev   This function must be called when initializing contracts by the deployer manually. ("polylemmer" is contract deployer's address.)
    ///        "battleField" address is stored in this contract to make some functions able to be called from only battleField.
    function setBattleField(address _battleField) external onlyPolylemmer {
        battleFieldIsSet = true;
        battleField = _battleField;
    }
}
