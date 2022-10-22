import {IPolylemmaPLM} from "./interfaces/IPolylemmaPLM.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract PolylemmaPLM is ERC20, IPolylemmaPLM {
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
