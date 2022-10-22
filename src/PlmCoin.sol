import {IPlmCoin} from "./interfaces/IPlmCoin.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PlmCoin is ERC20, IPlmCoin {
    address public treasury;

    constructor(address _treasury, uint256 _initialMint)
        ERC20("polylem", "PLM")
    {
        treasury = _treasury;
        _mint(_treasury, _initialMint);
    }

    function a(address ab) public view returns (uint256) {
        return balanceOf(ab);
    }
}
