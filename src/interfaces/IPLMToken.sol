import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPLMToken is IERC721, IERC721Enumerable {
    // TODO: factoryに移す。
    struct CharacterInfo {
        bytes20 name;
        string characterType;
        uint256 fromBlock;
        uint8 level;
        uint8 rarity;
        uint8[1] abilityIds;
    }

    event levelUped(CharacterInfo indexed characterInfo);

    function mint(bytes20 name) external returns (uint256);

    function burn(uint256 tokenId) external;

    function getAllTokenOwned(address account)
        external
        view
        returns (uint256[] memory);

    function getAllCharacterInfo() external returns (CharacterInfo[] calldata);

    // TODO: define in PLMToken.sol
    function getCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo calldata);

    function updateLevel(uint256 tokenId) external returns (uint8);

    function getNecessaryExp(uint256 tokenId) external view returns (uint256);

    function setMinter(address newMinter) external;

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
