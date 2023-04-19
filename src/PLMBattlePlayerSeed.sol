// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {PLMSeeder} from "./lib/PLMSeeder.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMBattleManager} from "./interfaces/IPLMBattleManager.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {PLMBattleField} from "./PLMBattleField.sol";
import {IPLMBattlePlayerSeed} from "./interfaces/IPLMBattlePlayerSeed.sol";

contract PLMBattlePlayerSeed is PLMBattleField, IPLMBattlePlayerSeed {
    constructor(
        IPLMDealer _dealer,
        IPLMToken _token,
        IPLMBattleManager _manager
    ) PLMBattleField(_dealer,_token,_manager) {
    }
    /// @notice Commit the player's seed to generate the tokenId for random slot.
    /// @param commitString: commitment string calculated by the player designated by player
    ///                      as keccak256(abi.encodePacked(msg.sender, playerSeed)).
    function commitPlayerSeed(
        bytes32 commitString
    ) external nonReentrantForEachBattle onlyPlayerOf {
        // Check that the battle hasn't started yet.
        require(
            _battleState() == BattleState.Standby,
            "Battle has already started."
        );
        address _enemyAddr = _enemyAddress();
        // Check that the player seed hasn't set yet.
        require(
            _randomSlotState(msg.sender) == RandomSlotState.NotSet,
            "playerSeed has already been set."
        );

        uint256 _battleId = _battleId();
        uint8 myId = _playerId();
        // Check that player seed commitment is in time.
        if (_isLateForPlayerSeedCommit()) {
            
            emit LatePlayerSeedCommitDetected(_battleId, myId);

            if (_randomSlotState(_enemyAddr) == RandomSlotState.NotSet) {
                // Both players are delayers.
                emit LatePlayerSeedCommitDetected(_battleId, 1-myId);
                _dealWithDelayersAndCancelBattle();
            } else {
                // Deal with the delayer (the player designated by player) and
                // cancel this battle.
                _dealWithDelayerAndCancelBattle(msg.sender);
            }
            return;
        }

        // Save commitment on the storage. The playerSeed of the player is hidden in the commit phase.
        manager.setPlayerSeedCommit(
            msg.sender,
            PlayerSeedCommit(commitString, bytes32(0))
        );

        // Emit the event that tells frontend that the player designated by player has committed.
        emit PlayerSeedCommitted(_battleId, myId);

        // Update the state of the random slot to be commited.
        manager.setPlayerInfoRandomSlotState(
            msg.sender,
            RandomSlotState.Committed
        );

        // Generate nonce after player committed the playerSeed.
        bytes32 nonce = PLMSeeder.randomFromBlockHash();

        // Emit the event that tells frontend that the randomSlotNonce is generated for the player designated
        // by player.
        emit RandomSlotNounceGenerated(_battleId, myId, nonce);

        manager.setPlayerInfoRandomSlotNonce(msg.sender, nonce);

        // If both players have already committed their player seeds, start the battle.
        if (_randomSlotState(_enemyAddr) == RandomSlotState.Committed) {
            manager.setBattleState(msg.sender, BattleState.InRound);
        }

        // Set the block number when the round starts.
        manager.setCommitFromBlock(msg.sender, block.number);
    }

    /// @param playerSeed: the choice the player designated by player committed in this round.
    ///                    bytes32(0) is not allowed.
    function revealPlayerSeed(
        bytes32 playerSeed
    ) external inRound readyForPlayerSeedReveal onlyPlayerOf {
        // The pointer to the commit log of the player designated by player.
        PlayerSeedCommit memory playerSeedCommit = manager.getPlayerSeedCommit(
            msg.sender
        );

        // Check the commit has coincides with the one stored on chain.
        require(
            keccak256(abi.encodePacked(msg.sender, playerSeed)) ==
                playerSeedCommit.commitString,
            "Commit hash doesn't coincide"
        );

        // Execute revealment
        manager.setPlayerSeedCommitValue(msg.sender, playerSeed);

        // Emit the event that tells frontend that the player designated by player has revealed.
        emit PlayerSeedRevealed(
            _battleId(),
            manager.getNumRounds(msg.sender),
            _playerId(),
            playerSeed
        );

        // Update the state of the random slot to be revealed.
        manager.setPlayerInfoRandomSlotState(
            msg.sender,
            RandomSlotState.Revealed
        );
    }
}

