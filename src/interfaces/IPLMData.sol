interface IPLMData {
    struct CharacterInfo {
        bytes32 name;
        uint256 imgId;
        uint256 fromBlock;
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] attributeIds;
    }

    function calcPower(
        uint8 numRounds,
        CharacterInfo calldata player1Char,
        uint8 player1LevelPoint,
        uint32 player1BondLevel,
        CharacterInfo calldata player2Char
    ) external view returns (uint32);

    function calcLevelPoint(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function calcRandomSlotLevel(CharacterInfo[4] calldata charInfos)
        external
        pure
        returns (uint8);

    ////////////////////////
    ///      GETTER      ///
    ////////////////////////

    function getPoolingPercentage(uint256 amount)
        external
        view
        returns (uint256);

    function getCharacterTypes() external view returns (string[] memory);

    function countCharacterTypes() external view returns (uint256);

    function getCumulativeCharacterTypeOdds()
        external
        view
        returns (uint8[] memory);

    function getAttributeRarities() external view returns (uint8[] memory);

    function countAttributes() external view returns (uint256);

    function getCumulativeAttributeOdds()
        external
        view
        returns (uint8[] memory);

    function getNumImg() external view returns (uint256);
}
