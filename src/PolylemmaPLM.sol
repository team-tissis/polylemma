import {IPolylemmaPLM} from "./interfaces/IPolylemmaPLM.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract PolylemmaPLM is IPolylemmaPLM, ERC20 {
    address public treasury;

    constructor(address _treasury, uint256 _firstMint) ERC20("polylem", "PLM") {
        treasury = _treasury;
        _mint(_deployer, _firstMint);
    }
}
