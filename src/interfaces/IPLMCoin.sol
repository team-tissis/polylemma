import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IPLMCoin is IERC20 {
    function mint(uint256 amount) external;

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////
    function setDealer(address _dealer) external;

    /////////////////////////
    /// FUNCTION FOR DEMO ///
    /////////////////////////

    // FIXME: remove this function after demo.
    function faucet(uint256 amount) external;
}
