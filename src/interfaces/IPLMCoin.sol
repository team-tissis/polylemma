import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IPLMCoin is IERC20 {
    function getSubscExpiredPoint(address account)
        external
        view
        returns (uint256);

    function banAccount(address account, uint256 banPeriod) external;
}
