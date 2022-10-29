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

    /// @notice when _checkpoint updated
    event CharacterInfoChanged(
        uint256 indexed tokenId,
        CharacterInfo oldCharacterInfo,
        CharacterInfo newCharacterInfo
    );

    // For debug
    error ErrorWithLog(string reason);

    function mint(bytes20 name) external returns (uint256);

    function burn(uint256 tokenId) external;

    function getAllTokenOwned(address account)
        external
        view
        returns (uint256[] memory);

    function getAllCharacterInfo() external returns (CharacterInfo[] calldata);

    function getCurrentCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo memory);

    function updateLevel(uint256 tokenId) external;

    function getNecessaryExp(uint256 tokenId) external view returns (uint256);

    function setDealer(address newDealer) external;

    function getPriorCharacterInfo(uint256 tokenId, uint256 blockNumber)
        external
        view
        returns (CharacterInfo memory);
    // function burn() external;
}
