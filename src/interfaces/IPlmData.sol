interface IPlmData {
    function getCharacterTypes() external view returns (string[] memory);

    function getAbilities() external view returns (string[] memory);

    function calcRarity(uint256 characterId, uint256[] calldata abilityIds)
        external
        view
        returns (uint256);

    function countCharacterType() external view returns (uint256);

    function countAbilities() external view returns (uint256);
}
