interface IPLMBattlePlayerSeed {
    function commitPlayerSeed(bytes32 commitString) external;
    function revealPlayerSeed(bytes32 playerSeed) external;
}
