import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IPLMData} from "./IPLMData.sol";

interface IPLMToken is IERC721, IERC721Enumerable {
    ////////////////////////
    ///      ENUMS       ///
    ////////////////////////

    /// @notice Enum to represent which checkpoint is reffered
    enum WhichCheckpoints {
        CharInfo, // 0
        TotalSupply // 1
    }

    ////////////////////////
    ///      STRUCTS     ///
    ////////////////////////

    /// @notice A checkpoint for marking change of characterInfo from a given block.
    struct CharInfoCheckpoint {
        uint256 fromBlock;
        CharacterInfo charInfo;
    }

    /// @notice A checkpoint for marking change of totalSupply from a given block.
    struct TotalSupplyCheckpoint {
        uint256 fromBlock;
        uint256 totalSupply;
    }

    /// @notice A struct to manage each token's information.
    struct CharacterInfo {
        uint8 level;
        uint8 rarity;
        uint8 characterTypeId;
        uint256 imgId;
        uint256 fromBlock;
        uint8[1] attributeIds;
        bytes32 name;
    }

    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event LevelUped(uint256 indexed tokenId, uint8 newLevel);

    /// @notice when _checkpoint updated
    event CharacterInfoChanged(
        uint256 indexed tokenId,
        CharacterInfo oldCharacterInfo,
        CharacterInfo newCharacterInfo
    );

    ////////////////////////
    ///      ERRORS      ///
    ////////////////////////

    // For debug
    error ErrorWithLog(string reason);

    function mint(bytes32 name) external returns (uint256);

    function updateLevel(uint256 tokenId, uint8 num) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function minimalizeCharInfo(
        CharacterInfo memory charInfo
    ) external view returns (IPLMData.CharacterInfoMinimal memory);

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getAllTokenOwned(
        address account
    ) external view returns (uint256[] memory);

    function getAllCharacterInfo()
        external
        view
        returns (CharacterInfo[] memory);

    function getElapsedFromBlock(
        uint256 tokenId
    ) external view returns (uint256);

    function getNecessaryExp(
        uint256 tokenId,
        uint8 num
    ) external view returns (uint256);

    function getDealer() external view returns (address);

    function getCurrentCharacterInfo(
        uint256 tokenId
    ) external view returns (CharacterInfo memory);

    function getPriorCharacterInfo(
        uint256 tokenId,
        uint256 blockNumber
    ) external view returns (CharacterInfo memory);

    function getImgURI(uint256 imgId) external view returns (string memory);

    function getPriorTotalSupply(
        uint256 blockNumber
    ) external view returns (uint256);

    function getNumImg() external view returns (uint256);

    function getDataAddr() external view returns (address);

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    function setDealer(address newDealer) external;

    function setNumImg(uint256 newImgNum) external;

    function setBaseImgURI(string calldata newBaseImgURI) external;
}
