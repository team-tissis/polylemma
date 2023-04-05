import {IPLMToken} from "./IPLMToken.sol";
import {IPLMTypes} from "./IPLMTypes.sol";
import {IPLMLevels} from "./IPLMLevels.sol";

interface IPLMData {
    ////////////////////////
    ///    STRUCTURES    ///
    ////////////////////////

    /// @notice Minimal character information used in data
    struct CharacterInfoMinimal {
        uint8 level;
        uint8 characterTypeId;
        uint8[1] attributeIds;
        uint256 fromBlock;
    }

    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event TypesDatabaseUpdated(address oldDatabase, address newDatabase);
    event LevelsDatabaseUpdated(address oldDatabase, address newDatabase);

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getCurrentBondLevel(
        uint8 level,
        uint256 fromBlock
    ) external view returns (uint32);

    function getPriorBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (uint32);

    function getDamage(
        uint8 numRounds,
        CharacterInfoMinimal calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfoMinimal calldata enemyChar
    ) external view returns (uint32);

    function getLevelPoint(
        CharacterInfoMinimal[4] calldata charInfos
    ) external view returns (uint8);

    function getRandomSlotLevel(
        CharacterInfoMinimal[4] calldata charInfos
    ) external view returns (uint8);

    function getCharacterTypes() external view returns (string[] memory);

    function getNumCharacterTypes() external view returns (uint256);

    function getCumulativeCharacterTypeOdds()
        external
        view
        returns (uint8[] memory);

    function getAttributeRarities() external view returns (uint8[] memory);

    function getNumAttributes() external view returns (uint256);

    function getCumulativeAttributeOdds()
        external
        view
        returns (uint8[] memory);

    function getNecessaryExp(
        CharacterInfoMinimal memory charInfo,
        uint8 num
    ) external view returns (uint256);

    function getRarity(
        uint8[1] memory attributeIds
    ) external view returns (uint8);

    function getTypeName(uint8 typeId) external view returns (string memory);

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    function setNewTypes(IPLMTypes newTypes) external;

    function setNewLevels(IPLMLevels newLevels) external;
}
