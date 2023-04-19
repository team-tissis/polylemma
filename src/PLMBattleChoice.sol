// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMBattleManager} from "./interfaces/IPLMBattleManager.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {PLMBattleField} from "./PLMBattleField.sol";
import {IPLMBattleChoice} from "./interfaces/IPLMBattleChoice.sol";

contract PLMBattleChoice is PLMBattleField, IPLMBattleChoice {
    constructor(
        IPLMDealer _dealer,
        IPLMToken _token,
        IPLMBattleManager _manager
    ) PLMBattleField(_dealer,_token,_manager) {
    }
     /// @notice Commit the choice (the character the player choose to use in the current round).
    /// @param commitString: commitment string calculated by the player designated by player
    ///                      as keccak256(abi.encodePacked(msg.sender, levelPoint, choice, blindingFactor)).
    function commitChoice(
        bytes32 commitString
    ) external nonReentrantForEachBattle inRound onlyPlayerOf {
        // Check that the player who want to commit haven't committed yet in this round.
        require(
            _playerState(msg.sender) == PlayerState.Standby,
            "Player isn't ready for choice commit"
        );

        uint8 numRounds = manager.getNumRounds(msg.sender);
        address _enemyAddr = _enemyAddress();
        uint256 _battleId = _battleId();
        uint8 myId = _playerId();

        // Check that choice commitment is in time.
        if (_isLateForChoiceCommit()) {
            emit LateChoiceCommitDetected(_battleId, numRounds, myId);

            if (_playerState(_enemyAddr) == PlayerState.Standby) {
                // Both players are delayers.
                emit LateChoiceCommitDetected(_battleId, numRounds, myId);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by player) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(msg.sender);
            }
            return;
        }

        // Save commitment on the storage. The choice of the player is hidden in the commit phase.
        manager.setChoiceCommit(
            msg.sender,
            ChoiceCommit(commitString, 0, Choice.Hidden)
        );

        // Emit the event that tells frontend that the player designated by player has committed.
        emit ChoiceCommitted(_battleId, numRounds, myId);

        // Update the state of the commit player to be committed.
        manager.setPlayerInfoState(msg.sender, PlayerState.Committed);

        if (_playerState(_enemyAddr) == PlayerState.Committed) {
            // both players have already committed.
            manager.setRevealFromBlock(msg.sender, block.number);
        }
    }

    /// @notice Reveal the committed choice by the player who committed it in this round.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    /// @param levelPoint: the levelPoint the player uses to the chosen character.
    /// @param choice: the choice the player designated by player committed in this round.
    ///                Choice.Hidden is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    function revealChoice(
        uint8 levelPoint,
        Choice choice,
        bytes32 bindingFactor
    )
        external
        nonReentrantForEachBattle
        inRound
        onlyPlayerOf
        readyForChoiceReveal
    {
        uint8 numRounds = manager.getNumRounds(msg.sender);
        // Choice.Hidden is not allowed for the choice passed to the reveal function.
        require(
            choice != Choice.Hidden,
            "Choice.Hidden isn't allowed when revealing"
        );
        address _enemyAddr = _enemyAddress();
        uint256 _battleId = _battleId();
        {
            uint8 myId = _playerId();
            // Check that choice revealment is in time.
            if (_isLateForChoiceReveal()) {
                emit LateChoiceRevealDetected(_battleId, numRounds, myId);

                if (_playerState(_enemyAddr) == PlayerState.Committed) {
                    // Both players are delayers.
                    emit LateChoiceRevealDetected(
                        _battleId,
                        numRounds,
                        1-myId
                    );
                    _dealWithDelayersAndCancelBattle();
                } else {
                    // Deal with the delayer (the player designated by player) and
                    // cancel this battle.
                    _dealWithDelayerAndCancelBattle(msg.sender);
                }
                return;
            }
        }

        // If the choice is the random slot, then random slot must have already been revealed.
        if (choice == Choice.Random) {
            require(
                _randomSlotState(msg.sender) == RandomSlotState.Revealed,
                "Random slot can't be used because playerSeed hasn't been revealed yet"
            );
        }

        {
            // The pointer to the commit log of the player designated by player.
            bytes32 choiceCommitString = manager.getChoiceCommitString(msg.sender);

            // Check the commit hash coincides with the one stored on chain.
            require(
                keccak256(
                    abi.encodePacked(msg.sender, levelPoint, choice, bindingFactor)
                ) == choiceCommitString,
                "Commit hash doesn't coincide"
            );
        }
        // Check that the levelPoint is less than or equal to the remainingLevelPoint.
        uint8 remainingLevelPoint = _remainingLevelPoint();
        uint8 myId = _playerId();
        if (levelPoint > remainingLevelPoint) {
            emit ExceedingLevelPointCheatDetected(
                _battleId,
                myId,
                remainingLevelPoint,
                levelPoint
            );

            // Deal with the chater (the player designated by player) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(msg.sender);
            return;
        }

        // Subtract revealed levelPoint from remainingLevelPoint
        manager.subtractPlayerInfoRemainingLevelPoint(msg.sender, levelPoint);

        // Check that the chosen slot hasn't been used yet.
        // If the revealed slot has already used, then end this match and ban the player designated by player.
        if (
            (choice == Choice.Random && _randomSlotUsedRound(msg.sender) > 0) ||
            (choice != Choice.Random &&
                _fixedSlotUsedRoundByIdx(msg.sender, uint8(choice)) > 0)
        ) {
            emit ReusingUsedSlotCheatDetected(_battleId, myId, choice);

            // Deal with the chater (the player designated by player) and cancel
            // this battle.
            _dealWithCheaterAndCancelBattle(msg.sender);
            return;
        }

        // Execute revealment
        manager.setChoiceCommitLevelPoint(msg.sender, levelPoint);
        manager.setChoiceCommitChoice(msg.sender, choice);

        // Emit the event that tells frontend that the player designated by player has revealed.
        emit ChoiceRevealed(
            _battleId,
            numRounds,
            myId,
            levelPoint,
            choice
        );

        // Update the state of the reveal player to be Revealed.
        manager.setPlayerInfoState(msg.sender, PlayerState.Revealed);

        // If both players have already revealed their choices, then proceed to the damage
        // calculation.
        if (_playerState(_enemyAddr) == PlayerState.Revealed) {
            _stepRound();
        }
    }


}
