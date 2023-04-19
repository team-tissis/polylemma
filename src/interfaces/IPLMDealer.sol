import {IPLMGacha} from "./IPLMGacha.sol";

interface IPLMDealer is IPLMGacha {
    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////
    event SubscExtended(
        address indexed account,
        uint256 beforeBlock,
        uint256 extendedBlock
    );

    event SubscShortened(
        address indexed account,
        uint256 beforeBlock,
        uint256 shortenedBlock
    );

    event AccountCharged(
        address indexed charger,
        uint256 chargeAmount,
        uint256 poolingAmount
    );

    event RewardAmountReduced(
        address indexed payee,
        uint256 virtualAmount,
        uint256 realAmount
    );

    ////////////////////////////////
    /// FUNCTIONS ABOUT FINANCES ///
    ////////////////////////////////

    function balanceOfMatic() external view returns (uint256);

    function withdraw(uint256 amount) external;

    function mintAdditionalCoin(uint256 amount) external;

    ///////////////////////////////
    /// FUNCTIONS ABOUT STAMINA ///
    ///////////////////////////////

    function consumeStaminaForBattle(address player) external;

    function restoreFullStamina(address player) external;

    function refundStaminaForBattle(address player) external;

    function getCurrentStamina(address player) external view returns (uint8);

    function getStaminaMax() external pure returns (uint8);

    ////////////////////////////////////
    /// FUNCTIONS ABOUT SUBSCRIPTION ///
    ////////////////////////////////////

    function subscIsExpired(address account) external view returns (bool);

    function extendSubscPeriod() external;

    function banAccount(address account, uint256 banPeriod) external;

    function getSubscExpiredBlock(address account)
        external
        view
        returns (uint256);

    function getSubscRemainingBlockNum(address account)
        external
        view
        returns (uint256);

    function getSubscFeePerUnitPeriod() external pure returns (uint256);

    function getSubscUnitPeriodBlockNum() external pure returns (uint256);

    //////////////////////////////////
    /// FUNCTIONS ABOUT CHARGEMENT ///
    //////////////////////////////////

    function charge() external payable;

    //////////////////////////////////////////////////////////////////////////////
    /// FUNCTIONS USED BY BATTLE FIELD CONTRACT TO CALCULATE REWARD FOR WINNER ///
    //////////////////////////////////////////////////////////////////////////////

    function payReward(address winner, uint256 amount) external;

    ////////////////////////////
    ///         SETTERS      ///
    ////////////////////////////

    function setMatchOrganizer(address _matchOrganizer) external;

    function setPLMBattleContracts(address _battleChoice,  address _battlePlayerSeed, address _battleReporter, address _battleStarter) external;
}
