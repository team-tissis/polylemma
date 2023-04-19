
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

interface IPLMBattleReporter {
    // FIXME: battleId and other state variables turn into getter

    /// @notice Function to report enemy player for late Seed Commit.
    function reportLatePlayerSeedCommit() external;
    /// @notice Function to report enemy player for late commitment.
    function reportLateChoiceCommit() external;

    /// @notice Function to report enemy player for late revealment.
    /// @dev This function is prepared to deal with the case that one of the player
    ///      don't reveal his/her choice and it locked the battle forever.
    ///      In this case, if the enemy (honest) player report him/her after the
    ///      choice revealmenet timelimit, then the delayer will be banned,
    ///      the battle will be canceled, and the stamina of the honest player will
    ///      be refunded.
    function reportLateReveal() external;

}
