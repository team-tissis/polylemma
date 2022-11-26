interface IPLMTypes {
    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event NewTypeAdded(uint8 typeId, string name, uint8 odds);

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getTypeCompatibility(uint8 playerTypeId, uint8 enemyTypeId)
        external
        view
        returns (uint8, uint8);

    function getTypeName(uint8 typeId) external view returns (string memory);

    function getNumCharacterTypes() external view returns (uint8);

    function getCharacterTypeOdds() external view returns (uint8[] memory);

    function getCharacterTypes() external view returns (string[] memory);

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    function setNewType(string calldata name, uint8 odds) external;
}
