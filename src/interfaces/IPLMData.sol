interface IPLMData {
    ////////////////////////
    ///      STRUCTS     ///
    ////////////////////////

    // TODO: member変数の入れ替え
    struct CharacterInfo {
        bytes32 name;
        uint256 imgId;
        uint256 fromBlock;
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] attributeIds;
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getDamage(
        uint8 numRounds,
        CharacterInfo calldata playerChar,
        uint8 playerLevelPoint,
        uint32 playerBondLevel,
        CharacterInfo calldata enemyChar
    ) external view returns (uint32);

    function getLevelPoint(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function getRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function getPoolingPercentage(uint256 amount)
        external
        view
        returns (uint256);

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

    function getNumImg() external view returns (uint256);
}
