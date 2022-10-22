import {IERC721} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IPolylemmaToken is IERC721 {
    function mint() external returns (uint256);

    function burn() external;
}
