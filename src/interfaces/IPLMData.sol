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

    function getCharacterTypes() external view returns (string[] memory);

    function countCharacterType() external view returns (uint256);

    function getCharacterTypeOdds() external view returns (uint8[] memory);

    function getAttributes() external view returns (string[] memory);

    function getAttributeRarities() external view returns (uint8[] calldata);

    function countAttributes() external view returns (uint256);

    function getNumOddsCharacterType() external view returns (uint256);

    function getAttributeOdds() external view returns (uint8[] calldata);

    function getNumImg() external view returns (uint256);

    function numOddsAttribute() external view returns (uint256);

    function calcPower(
        uint8 numRounds,
        CharacterInfo calldata player1Char,
        uint8 player1LevelPoint,
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

    function getPoolingPercentage(uint256 amount)
        external
        view
        returns (uint256);
}
