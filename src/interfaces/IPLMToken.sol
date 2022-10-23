import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";

interface IPLMToken is IERC721 {
    struct CharacterInfo {
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] abilityIds;
    }

    function mint() external returns (uint256);

    function getAllCharacterInfo() external returns (CharacterInfo[] calldata);

    // TODO: define in PLMToken.sol
    function getCharacterInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo calldata);

    function getTotalSupply() external returns (uint256);
    // function burn() external;
}
