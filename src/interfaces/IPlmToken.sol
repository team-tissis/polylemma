import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

interface IPlmToken is IERC721 {
    function mint() external returns (uint256);

    // function burn() external;
}
