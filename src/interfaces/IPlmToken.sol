import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

interface IPolylemmaToken is IERC721 {
    function mint() external returns (uint256);

    function burn() external;
}
