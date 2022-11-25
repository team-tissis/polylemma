import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IPLMData} from "./IPLMData.sol";

interface IPLMToken is IERC721, IERC721Enumerable, IPLMData {
    /// @notice Enum to represent battle's state.
    enum WhichCheckpoints {
        CharInfo, // 0
        TotalSupply, // 1
    }
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

    event levelUped(CharacterInfo indexed characterInfo);

    /// @notice when _checkpoint updated
    event CharacterInfoChanged(
        uint256 indexed tokenId,
        CharacterInfo oldCharacterInfo,
        CharacterInfo newCharacterInfo
    );

    // For debug
    error ErrorWithLog(string reason);

    function mint(bytes32 name) external returns (uint256);

    function updateLevel(uint256 tokenId) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getCurrentBondLevel(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32);

    function getPriorBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) external pure returns (uint32);

    function getAllTokenOwned(address account)
        external
        view
        returns (uint256[] memory);

    function getAllCharacterInfo()
        external
        view
        returns (CharacterInfo[] memory);

    function getElapsedFromBlock(uint256 tokenId)
        external
        view
        returns (uint256);

    function getNecessaryExp(uint256 tokenId) external view returns (uint256);

    function getDealer() external view returns (address);

    function getCurrentCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo memory);

    function getPriorCharacterInfo(uint256 tokenId, uint256 blockNumber)
        external
        view
        returns (CharacterInfo memory);

    function getImgURI(uint256 imgId) external returns (string memory);

    function getPriorTotalSupply(uint256 blockNumber)
        external
        view
        returns (uint256);

    ////////////////////////
    ///      SETTER      ///
    ////////////////////////

    function setDealer(address newDealer) external;

    function setNumImg(uint256 newImgNum) external;

    function setBaseImgURI(string calldata newBaseImgURI) external;
}
