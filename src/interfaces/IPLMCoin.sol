import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IPLMCoin is IERC20 {
    function getSubscExpiredPoint(address account)
        external
        view
        returns (uint256);

    function subscIsExpired(address account) external view returns (bool);

    function updateSubsc() external returns (uint256);

    function banAccount(address account, uint256 banPeriod) external;

    function getSubscFee() external view returns (uint256);

    function getSubscDuration() external view returns (uint256);

    function mint(uint256 amount) external;

    function setTreasury(address _treasury) external;
}
