import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPLMToken is IERC721, IERC721Enumerable {
    // TODO: factoryに移す。
    struct CharacterInfo {
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] abilityIds;
    }

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function getAllCharacterInfo() external returns (CharacterInfo[] calldata);

    // TODO: define in PLMToken.sol
    function getCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo calldata);

    function setMinter(address newMinter) external;

    // function burn() external;
}
