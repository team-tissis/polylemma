import {IPolylemmaData} from "./interfaces/IPolylemmaData.sol";

contract PolylemmaData is IPolylemmaData {
    // TODO: monsterblocksのmonster名で仮置きした
    string[] public characters = [
        "hikozaru",
        "pocchama",
        "naetoru",
        "hitokage",
        "zenigame",
        "fushigidane"
    ];

    string[] public abilities = ["mouka", "shinryoku", "gekiryu"];

    function getCharacters() external view override returns (string[] memory) {
        return characters;
    }

    function getAbilities() external view override returns (string[] memory) {
        return abilities;
    }

    function countCharacters() external view override returns (uint256) {
        return characters.length;
    }

    function countAbilities() external view override returns (uint256) {
        return abilities.length;
    }
}
