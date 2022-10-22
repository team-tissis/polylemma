interface IPlmData {
    function getCharacterTypes() external view returns (string[] memory);

    function countCharacterType() external view returns (uint256);

    function getAbilities() external view returns (string[] memory);

    function countAbilities() external view returns (uint256);

    function calcRarity(uint8 characterId, uint8[1] calldata abilityIds)
        external
        view
        returns (uint8);

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
}
