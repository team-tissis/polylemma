
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMBattleManager} from "./interfaces/IPLMBattleManager.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {PLMBattleField} from "./PLMBattleField.sol";
import {IPLMBattleReporter} from "./interfaces/IPLMBattleReporter.sol";

contract PLMBattleReporter is PLMBattleField, IPLMBattleReporter {
    constructor(
        IPLMDealer _dealer,
        IPLMToken _token,
        IPLMBattleManager _manager
    ) PLMBattleField(_dealer,_token,_manager) {
    }
    // FIXME: battleId and other state variables turn into getter

    /// @notice Function to report enemy player for late Seed Commit.
    function reportLatePlayerSeedCommit() external standby onlyPlayerOf {
        // Detect enemy player's late player seed commit.

        require(
            _randomSlotState(_enemyAddress()) == RandomSlotState.NotSet &&
                _isLateForPlayerSeedCommit(),
            "Reported player isn't late"
        );

        emit LatePlayerSeedCommitDetected(_battleId(), _enemyId());

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddress());
    }

    /// @notice Function to report enemy player for late commitment.
    function reportLateChoiceCommit() external inRound onlyPlayerOf {
        // Detect enemy player's late choice commit.
        require(
            _playerState(_enemyAddress()) == PlayerState.Standby &&
                _isLateForChoiceCommit(),
            "Reported player isn't late"
        );

        emit LateChoiceCommitDetected(
            _battleId(),
            manager.getNumRounds(msg.sender),
            manager.getPlayerId(_enemyAddress())
        );

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddress());
    }

    /// @notice Function to report enemy player for late revealment.
    /// @dev This function is prepared to deal with the case that one of the player
    ///      don't reveal his/her choice and it locked the battle forever.
    ///      In this case, if the enemy (honest) player report him/her after the
    ///      choice revealmenet timelimit, then the delayer will be banned,
    ///      the battle will be canceled, and the stamina of the honest player will
    ///      be refunded.
    function reportLateReveal() external inRound onlyPlayerOf {
        // Detect enemy player's late revealment.
        require(
            _playerState(_enemyAddress()) == PlayerState.Committed &&
                _isLateForChoiceReveal(),
            "Reported player isn't late"
        );

        emit LateChoiceRevealDetected(
            _battleId(),
            manager.getNumRounds(msg.sender),
            manager.getPlayerId(_enemyAddress())
        );

        // Deal with the delayer (enemy player) and cancel this battle.
        _dealWithDelayerAndCancelBattle(_enemyAddress());
    }


}
