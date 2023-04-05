// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Math} from "openzeppelin-contracts/utils/math/math.sol";

import {PLMGacha} from "./subcontracts/PLMGacha.sol";

import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";

contract PLMDealer is PLMGacha, IPLMDealer {
    using Math for uint256;

    /// @notice subscription Fee (PLMCoin) for one period.
    uint256 constant SUBSC_FEE_PER_UNIT_PERIOD = 10;

    /// @notice block number of subscription period unit (30 days).
    uint256 constant SUBSC_UNIT_PERIOD_BLOCK_NUM = 1296000;

    /// @notice The value used to avoid undeflow in calculation about subscription.
    /// @dev This value should be larger than the maximum value of block numbers subtracted
    ///      when the player is banned. Currently, it is set to SUBSC_UNIT_PERIOD_BLOCK_NUM.
    uint256 constant SUBSC_OFFSET = 1296000;

    /// @notice The number of blocks needed to recover unit stamina. (10 min).
    uint16 constant STAMINA_RESTORE_SPEED = 300;

    /// @notice The maximum value of stamina.
    uint8 constant STAMINA_MAX = 100;

    /// @notice The value used to avoid underflow in calculation about stamina.
    uint16 constant STAMINA_OFFSET = 30000;

    //// @notice the fee to restore stamina (unit: PLM)
    uint8 constant RESTORE_STAMINA_FEE = 5;

    /// @notice The amount of stamina consumed when playing battle with other players.
    uint8 constant STAMINA_PER_BATTLE = 10;

    /// @notice The length of the period preventing accounts from re-charging (1 day).
    uint16 constant CHARGE_LOCKED_PERIOD = 43200;

    /// @notice Progressive taxation of coin issuance through billing
    uint256[] poolingPercentageTable = [5, 10, 20, 23, 33, 40, 45];

    /// @notice contract address of the matchOrganizer.
    address matchOrganizer;

    /// @notice contract address of the battleField.
    address battleField;

    /// @notice contract address of the dealer of polylemma.
    address dealer;

    /// @notice admin's address
    address polylemmers;

    /// @notice Mapping from each account to one's subscription expired block number.
    mapping(address => uint256) subscExpiredBlock;

    /// @notice "The block number when the stamina is zero for each player" + "STAMINA_OFFSET"
    /// @dev STAMINA_OFFSET is added to simplify the implementation by not handling underflow errors.
    mapping(address => uint256) staminaFromBlock;

    /// @notice The block number of the player's previous charge.
    mapping(address => uint256) previousChargeBlock;

    constructor(IPLMToken _token, IPLMCoin _coin) {
        dealer = address(this);
        polylemmers = msg.sender;
        token = _token;
        coin = _coin;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "sender != polylemmers");
        _;
    }
    modifier onlyMatchOrganizer() {
        require(msg.sender == matchOrganizer, "sender != matchOrganizer");
        _;
    }
    modifier onlyBattleField() {
        require(msg.sender == battleField, "sender != battleField");
        _;
    }

    /// @notice Check that enough time has passed from the previous charge.
    modifier rechargeable() {
        // block.number == 0 means the sender hasn't charged yet.
        require(
            previousChargeBlock[msg.sender] == 0 ||
                previousChargeBlock[msg.sender] + CHARGE_LOCKED_PERIOD <=
                block.number,
            "charge is locked"
        );
        _;
    }

    ////////////////////////////////
    /// FUNCTIONS ABOUT FINANCES ///
    ////////////////////////////////

    /// @notice balance of sender MATIC
    function balanceOfMatic() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice withdraw MATIC send to this contract by player
    function withdraw(uint256 amount) external onlyPolylemmers {
        // Total amount of MATIC this contract owns.
        uint256 totalAmount = address(this).balance;

        // Check that withdrawal is possible.
        require(amount <= totalAmount, "cannot withdraw in excess of balance");

        // Execute withdrawal.
        (bool success, ) = payable(dealer).call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    /// @notice This function is used when the amount of PLMCoin the dealer has is insufficient.
    function mintAdditionalCoin(uint256 amount) external onlyPolylemmers {
        coin.mint(amount);
    }

    ///////////////////////////////
    /// FUNCTIONS ABOUT STAMINA ///
    ///////////////////////////////

    /// @dev This function calculate remained stamina ftom retained block numbers
    ///      and stamina restoring speed.
    function _currentStamina(address player) internal view returns (uint8) {
        // if the player doesn't consume any stamina, it's ok because the below
        // calculation always output STAMINA_MAX.
        return
            uint8(
                ((block.number +
                    uint256(STAMINA_OFFSET) -
                    staminaFromBlock[player]) / STAMINA_RESTORE_SPEED).min(
                        STAMINA_MAX
                    )
            );
    }

    /// @dev restore the stamina to the max value of the stamina.
    function _restoreStamina(address player) internal {
        // because staminaFromBlock preserves the value of block number that indicate
        // the time when stamina is zero + STAMINA_OFFSET.
        // setting staminaFromBlock by block.number means that the current stamina is
        // ((block.number + STAMINA_OFFSET) - staminaFromBlock) / STAMINA_RESTORE_SPEED
        // = STAMINA_MAX !!
        staminaFromBlock[player] = block.number;
    }

    /// @dev set stamina max value
    /// @dev Function called in charge() that is the first function users call when they join this game.
    function initializeStamina(address player) internal {
        _restoreStamina(player);
    }

    /// @notice need approvement of coin to dealer
    function restoreFullStamina(address player) external nonReentrant {
        require(
            _currentStamina(player) < STAMINA_MAX,
            "player's stamina is full"
        );
        coin.transferFrom(msg.sender, dealer, RESTORE_STAMINA_FEE);
        _restoreStamina(player);
    }

    /// @dev rewrite the retained block numbers that indicate the time when stamina is zero to shift it into the feature
    function consumeStaminaForBattle(
        address player
    ) external onlyMatchOrganizer {
        require(
            block.number + STAMINA_OFFSET >=
                staminaFromBlock[player] +
                    STAMINA_PER_BATTLE *
                    STAMINA_RESTORE_SPEED,
            "sender does not have enough stamina"
        );

        uint8 currentStamina = _currentStamina(player);
        if (currentStamina < STAMINA_MAX) {
            // case1: stamina < stamina_max
            // in this case, we should shift the staminaFromBlock by the amount
            // corresponding to the stamina consumed per battle.
            staminaFromBlock[player] +=
                STAMINA_PER_BATTLE *
                STAMINA_RESTORE_SPEED;
        } else {
            // case2: stamina >= stamina_max
            // in this case, we jump to the point that stamina is MAX
            // (that is block.number) and comsume stamina with amount
            // STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED
            staminaFromBlock[player] =
                block.number +
                STAMINA_PER_BATTLE *
                STAMINA_RESTORE_SPEED;
        }
    }

    /// @notice function called when the battle did not end normally
    function refundStaminaForBattle(address player) external onlyBattleField {
        // This function is called after the consumeStaminaPerBattle function call.
        // It means that
        // staminaFromBlock[player] > block.number + STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED
        //                          >= 0 + STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED
        // we can implement refunding by just subtracting STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED
        // without handling underflow.
        // the below require should always be passed.
        require(
            staminaFromBlock[player] >=
                STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED,
            "invalid call of refundStamina"
        );
        staminaFromBlock[player] -= STAMINA_PER_BATTLE * STAMINA_RESTORE_SPEED;
    }

    /// @dev - This function calculate remained stamina ftom retained block numbers and stamina restoring speed.
    ///        This contract restores the block number at the time when each player's stamina was zero.
    ///      - When the current block number is less than max stamina point, this function return max stamina.
    function getCurrentStamina(address player) external view returns (uint8) {
        return _currentStamina(player);
    }

    function getStaminaMax() external pure returns (uint8) {
        return STAMINA_MAX;
    }

    function getStaminaPerBattle() external pure returns (uint8) {
        return STAMINA_PER_BATTLE;
    }

    function getRestoreStaminaFee() external pure returns (uint8) {
        return RESTORE_STAMINA_FEE;
    }

    ////////////////////////////////////
    /// FUNCTIONS ABOUT SUBSCRIPTION ///
    ////////////////////////////////////

    /// @notice Function to get the subscription expired block number of the account.
    function _subscIsExpired(address account) internal view returns (bool) {
        return block.number + SUBSC_OFFSET > subscExpiredBlock[account];
    }

    /// @notice Function to return whether the account's subscription is expired or not.
    function subscIsExpired(address account) external view returns (bool) {
        return _subscIsExpired(account);
    }

    /// @notice Function to extend subscription period.
    /// @dev Need approvement of coin to dealer
    function extendSubscPeriod() external {
        uint256 currentExpiredBlock = subscExpiredBlock[msg.sender];

        // TODO: modify here from transfer to safeTransfer.
        // Transfer PLMCoin from user to dealer as subscription fee.
        coin.transferFrom(msg.sender, dealer, SUBSC_FEE_PER_UNIT_PERIOD);

        if (_subscIsExpired(msg.sender)) {
            // case1: subsc is expired
            // in this case, start subscription unit from the current time
            // (that is block.number + SUBSC_OFFSET).
            subscExpiredBlock[msg.sender] =
                block.number +
                SUBSC_OFFSET +
                SUBSC_UNIT_PERIOD_BLOCK_NUM;
        } else {
            // case2: subsc is ongoing.
            // in this case, just extend the period by SUBSC_UNIT_PERIOD_BLOCK_NUM.
            subscExpiredBlock[msg.sender] += SUBSC_UNIT_PERIOD_BLOCK_NUM;
        }

        emit SubscExtended(
            msg.sender,
            currentExpiredBlock,
            subscExpiredBlock[msg.sender]
        );
    }

    /// @notice Function to ban account for the period designated by banPeriod.
    /// @dev This function is called from BattleField contract when cheating detected.
    function banAccount(
        address account,
        uint256 banPeriod
    ) external onlyBattleField {
        uint256 currentExpiredBlock = subscExpiredBlock[account];

        // We should only deal with the case that the subsc of the banned player is ongoing.
        if (!_subscIsExpired(account)) {
            subscExpiredBlock[account] -= banPeriod;
        }

        emit SubscShortened(
            msg.sender,
            currentExpiredBlock,
            subscExpiredBlock[account]
        );
    }

    /// @notice Function to get the subscription expired block number of the account.
    function getSubscExpiredBlock(
        address account
    ) external view returns (uint256) {
        return subscExpiredBlock[account];
    }

    /// @notice Function to get the number blocks remained until subscription expired block.
    function getSubscRemainingBlockNum(
        address account
    ) external view returns (uint256) {
        uint256 remainingBlockNum = block.number + SUBSC_OFFSET <
            subscExpiredBlock[account]
            ? subscExpiredBlock[account] - block.number - SUBSC_OFFSET
            : 0;
        return remainingBlockNum;
    }

    function getSubscFeePerUnitPeriod() external pure returns (uint256) {
        return SUBSC_FEE_PER_UNIT_PERIOD;
    }

    function getSubscUnitPeriodBlockNum() external pure returns (uint256) {
        return SUBSC_UNIT_PERIOD_BLOCK_NUM;
    }

    //////////////////////////////////
    /// FUNCTIONS ABOUT CHARGEMENT ///
    //////////////////////////////////

    /// @notice Function to transfer minted PLMCoin to the charger and PLMCoin pool.
    /// @dev The distribution is determined in a progressive taxation manner.
    /// @param account: game player's account who charged MATIC to get PLMCoin.
    /// @param totalAmount: sum of the amount of PLMCoin distributed to the player and PLMCoin pool.
    function _transferPLMCoinWithPooling(
        address account,
        uint256 totalAmount
    ) internal {
        // Calcuate how much PLMCoin are stored in the PLMCoin pool.
        uint256 leftAmount = _calcLeftAmount(totalAmount);
        uint256 poolingAmount = totalAmount - leftAmount;

        // Transfer rest of the minted PLMCoin to the account who charged.
        coin.transfer(account, leftAmount);
        emit AccountCharged(account, totalAmount, poolingAmount);
    }

    /// @notice Function to calculate the unpooled amount.
    function _calcLeftAmount(
        uint256 totalAmount
    ) internal view returns (uint256) {
        // get the pooling percentage from PLMData contract.
        uint256 poolingPercentage = _poolingPercentage(totalAmount);
        return (totalAmount * (100 - poolingPercentage)) / 100;
    }

    /// @notice get the percentage of pooling of PLMCoins minted when player charged
    ///         MATIC
    function _poolingPercentage(
        uint256 amount
    ) internal view returns (uint256) {
        if (0 < amount && amount <= 80) {
            return poolingPercentageTable[0];
        } else if (80 < amount && amount <= 160) {
            return poolingPercentageTable[1];
        } else if (160 < amount && amount <= 200) {
            return poolingPercentageTable[2];
        } else if (200 < amount && amount <= 240) {
            return poolingPercentageTable[3];
        } else if (240 < amount && amount <= 280) {
            return poolingPercentageTable[4];
        } else if (280 < amount && amount <= 320) {
            return poolingPercentageTable[5];
        } else {
            return poolingPercentageTable[6];
        }
    }

    /// @notice Function used by game users to charge MATIC to get PLMCoin.
    /// @dev The price of PLMCoin is pegged to MATIC as 1:1.
    ///      If enough time hasn't passed from the previous chargement, then this
    ///      operation cannot be executable. This violation is detected in the
    ///      modifier (rechargeable).
    function charge() external payable rechargeable {
        // This is the first function users call when they join this game.
        // functions to initialize smothing are called here.
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

        // Record the block number of current chargement.
        previousChargeBlock[msg.sender] = block.number;
    }

    //////////////////////////////////////////////////////////////////////////////
    /// FUNCTIONS USED BY BATTLE FIELD CONTRACT TO CALCULATE REWARD FOR WINNER ///
    //////////////////////////////////////////////////////////////////////////////

    /// @dev reward is paid from dealer conteract address
    ///      coin.transfer is not called directly bacause the function needs to be called by payer of reward, dealer.
    function _tryPayReward(
        address winner,
        uint256 amount
    ) internal returns (bool, uint256) {
        uint256 balance = coin.balanceOf(address(this));
        bool success = balance >= amount;
        uint256 rewardAmount = success ? amount : balance;
        coin.transfer(winner, rewardAmount);
        return (success, rewardAmount);
    }

    /// @notice Function to pay reward to battle winner address
    function payReward(address winner, uint256 amount) external {
        (bool success, uint256 rewardAmount) = _tryPayReward(winner, amount);
        if (!success) {
            emit RewardAmountReduced(winner, amount, rewardAmount);
        }
    }

    ////////////////////////////
    ///        SETTERS       ///
    ////////////////////////////

    /// @notice set match organizer contract address, function called by only Polylemmers EOA
    /// @dev   This function must be called when initializing contracts by the deployer manually. ("polylemmers" is contract deployer's address.)
    ///        "matchOrganizer" address is stored in this contract to make some functions able to be called from only matchOrganizer.
    function setMatchOrganizer(
        address _matchOrganizer
    ) external onlyPolylemmers {
        matchOrganizer = _matchOrganizer;
    }

    /// @notice set battle field contract address, function called by only Polylemmers EOA
    /// @dev   This function must be called when initializing contracts by the deployer manually. ("polylemmers" is contract deployer's address.)
    ///        "battleField" address is stored in this contract to make some functions able to be called from only battleField.
    function setBattleField(address _battleField) external onlyPolylemmers {
        battleField = _battleField;
    }
}
