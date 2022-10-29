import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IPLMData} from "./IPLMData.sol";

interface IPLMToken is IERC721, IERC721Enumerable, IPLMData {
    /// @notice A checkpoint for marking change of characterInfo from a given block.
    struct Checkpoint {
        uint256 fromBlock;
        CharacterInfo charInfo;
    }

    event levelUped(CharacterInfo indexed characterInfo);

    // For debug
    error ErrorWithLog(string reason);

    function mint(bytes20 name) external returns (uint256);

    function burn(uint256 tokenId) external;

    function getAllTokenOwned(address account)
        external
        view
        returns (uint256[] memory);

    function getAllCharacterInfo() external returns (CharacterInfo[] calldata);

    function getCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo calldata);

    function updateLevel(uint256 tokenId) external returns (uint8);

    function getNecessaryExp(uint256 tokenId) external view returns (uint256);

    function setDealer(address newDealer) external;

    function getCurrentCharInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo memory);

    function getPriorCharInfo(uint256 tokenId, uint256 blockNumber)
        external
        view
        returns (CharacterInfo memory);
    // function burn() external;
}
