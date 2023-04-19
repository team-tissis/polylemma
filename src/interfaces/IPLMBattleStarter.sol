interface IPLMBattleStarter {
    function startBattle(
        address homeAddr,
        address visitorAddr,
        uint256 homeFromBlock,
        uint256 visitorFromBlock,
        uint256[4] calldata homeFixedSlots,
        uint256[4] calldata visitorFixedSlots
    ) external;

        //////////////////////////
    /// FUNCTIONS FOR DEMO ///
    //////////////////////////

    // FIXME: remove this function after demo.
    function forceInitBattle() external;
}
