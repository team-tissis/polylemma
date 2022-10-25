import {IPLMToken} from "../interfaces/IPLMToken.sol";

interface IPLMData {
    function getCharacterTypes() external view returns (string[] memory);

    function countCharacterType() external view returns (uint256);

    function getAbilities() external view returns (string[] memory);

    function countAbilities() external view returns (uint256);

    function calcRarity(uint8 characterId, uint8[1] calldata abilityIds)
        external
        pure
        returns (uint8);

    function calcNecessaryExp(IPLMToken.CharacterInfo calldata charInfo)
        external
        pure
        returns (uint256);

    function getCharacterTypeOdds()
        external
        view
        returns (uint8[] calldata characterTypeOdds);

    function numOddsCharacterType() external view returns (uint256);

    function getAbilityOdds()
        external
        view
        returns (uint8[] calldata abilityOdds);

    function numOddsAbility() external view returns (uint256);

    function calcBattleResult(
        IPLMToken.CharacterInfo calldata aliceChar,
        IPLMToken.CharacterInfo calldata bobChar
    ) external pure returns (uint8 aliceDamage, uint8 bobDamage);

    function calcLevelPoint(IPLMToken.CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8 levelPoint);

    function getTaxRate(uint256 amount)
        external
        view
        returns (uint256, uint256);
}
