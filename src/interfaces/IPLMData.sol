interface IPLMData {
    struct CharacterInfo {
        bytes32 name;
        uint256 imgId;
        uint256 fromBlock;
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] abilityIds;
    }

    function getCharacterTypes() external view returns (string[] memory);

    function countCharacterType() external view returns (uint256);

    function getAbilities() external view returns (string[] memory);

    function countAbilities() external view returns (uint256);

    function getCharacterTypeOdds() external view returns (uint8[] calldata);

    function getNumOddsCharacterType() external view returns (uint256);

    function getAbilityOdds() external view returns (uint8[] calldata);

    function getNumOddsAbility() external view returns (uint256);

    function getNumImg() external view returns (uint256);

    function calcBattleResult(
        CharacterInfo calldata aliceChar,
        CharacterInfo calldata bobChar
    ) external pure returns (uint8, uint8);

    function calcLevelPoint(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function calcRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function getPoolingPercentage(uint256 amount)
        external
        view
        returns (uint256);
}
