import {IPlmData} from "./interfaces/IPlmData.sol";

contract PlmData is IPlmData {
    // TODO: monsterblocksのmonster名で仮置きした
    // TODO: 入替可能なようにconstructorで初期化&setHogeで入替可能にするべき
    string[] public characterTypes = [
        "fire",
        "grass",
        "water",
        "dark",
        "light"
    ];

    string[] public abilities = ["mouka", "shinryoku", "gekiryu"];

    uint8[] public characterTypeOdds;
    uint8[] public abilityOdds;

    function getCharacterTypes()
        external
        view
        override
        returns (string[] memory)
    {
        return characterTypes;
    }

    function getAbilities() external view override returns (string[] memory) {
        return abilities;
    }

    // TODO: not defined yet
    function calcRarity(uint256 characterId, uint256[] calldata abilityIds)
        external
        view
        override
        returns (uint256)
    {
        return 0;
    }

    function numOddsCharacterType() external view override returns (uint256) {
        return characterTypeOdds.length;
    }

    function numOddsAbility() external view override returns (uint256) {
        return abilityOdds.length;
    }
}
