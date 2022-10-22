// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract PLMBattleField is Ownable {
    /// @notice Struct to specify tokenIds of the party
    struct Party {
        uint256 fixedSlotId1;
        uint256 fixedSlotId2;
        uint256 fixedSlotId3;
        uint256 fixedSlotId4;
        uint256 randomSlotId1;
        uint256 randomSlotId2;
    }

    /// @notice Enum to represent player's choice of the character fighting in the next round.
    enum Choice {
        Secret,
        Fixed1,
        Fixed2,
        Fixed3,
        Fixed4,
        Random1,
        Random2
    }

    /// @notice Struct to represent the commitment of the choice.
    struct Commitment {
        bytes32 commitString;
        Choice choice;
    }

    /// @notice Players' states in each round.
    enum PlayerState {
        RoundStarted,
        Commited,
        Revealed,
        RoundSettled
    }

    event Commited(uint8 numRounds, uint8 playerIdx);
    event Revealed(uint8 numRounds, uint8 player, Choice choice);
    event BattleResult(uint8 numRounds, 
        uint8 winner,
        uint8 loser,
        uint8 winnerDamage,
        uint8 loserDamage
    );
    event BattleResultDraw(uint8 numRounds, uint8 damage);
    event BattleSettled(uint8 numRounds, uint8 winner, uint8 loser, uint8 winCount, uint8 loseCount);
    event BattleSettled(uint8 numRounds, uint8 count);

    /// @notice The number of winning needed to win the match.
    constant uint8 WIN_COUNT = 3;

    /// @notice The number of the maximum round.
    constant uint8 MAX_ROUNDS = 6;

    /// @notice dealer's address of polylemma.
    address payable dealer;

    /// @notice interface to the characters' information.
    IPLMToken PLMToken;

    /// @notice playerAddress of the players in the current battle match.
    address[2] playerAddress;

    /// @notice parties of the characters of the players.
    Party[2] parties;

    /// @notice states of the players (Commited, Revealed, etc...)
    PlayerState[2] playerStates;

    /// @notice counter of the winning.
    uint8[2] winCount;

    /// @notice number of rounds. (< 6)
    uint8 numRounds;

    /// @notice storage to store the commitment log in the current round.
    /// @dev Should we change this to the mapping whose key is the round number ?
    Commitment[2] commitLog;

    modifier onlyDealer() {
        require(msg.sender == dealer);
        _;
    }

    /// @notice Check whether the caller of the function is the valid account.
    /// @param playerIdx: the index used to designate the player. 0 or 1.
    modifier onlyPlayerOfIdx(uint8 playerIdx) {
        require(playerIdx == 0 || playerIdx == 1, "Invalid playerIdx.");
        require(
            msg.sender == playerAddress[playerIdx],
            "The caller player is not the valid account."
        );
        _;
    }

    /// @notice Check that both players have already commited in this round.
    modifier readyForRevealment(uint8 playerIdx) {
        require(
            playerStates[playerIdx] == PlayerState.Commited,
            "The player hasn't commited in this round yet."
        );
        uint8 enemyIdx = playerIdx == 0 ? 1 : 0;
        require(
            playerStates[enemyIdx] == PlayerState.Commited ||
                playerStates[enemyIdx] == PlayerState.Revealed,
            "The enemy player hasn't commited in this round yet."
        );
        _;
    }

    /// @notice Check that both players have already revealed in this round.
    modifier readyForBattle() {
        require(
            playerStates[0] == PlayerState.Revealed &&
                playerStates[1] == PlayerState.Revealed,
            "Both palyes have to reveal their choices before executing the battle."
        );
        _;
    }

    /// @notice Commit the choice (the character the player choose to use in the current round).
    /// @param playerIdx: the index used to designate the player. 0 or 1.
    /// @param commitString: commitment string calculated by the player designated by playerIdx
    ///                      as keccak256(abi.encodePacked(msg.sender, choice, blindingFactor)).
    function commit(uint8 playerIdx, bytes32 commitString)
        public
        onlyPlayerOfIdx(playerIdx)
    {
        // Check that the player who want to commit haven't commited yet in this round.
        require(
            playerStates[playerIdx] == PlayerState.RoundStarted,
            "This player is not in the state to commit in this round."
        );

        // Save commitment on the storage. The choice of the player is hidden in the commit phase.
        commitLog[playerIdx] = Commitment(commitString, Choice.Secret);

        // Emit the event that tells frontend that the player designated by playerIdx has commited.
        emit Commited(numRounds, playerIdx);

        // Update the state of the commit player to be Commited.
        playerStates[playerIdx] = PlayerState.Commited;
    }

    /// @notice Reveal the commited choice by the player who commited it in this round.
    /// @param playerIdx: the index used to designate the player. 0 or 1.
    /// @param choice: the choice the player designated by playerIdx commited in this round.
    ///                Choice.Secret is not allowed.
    /// @param bindingFactor: the secret factor (one-time) used in the generation of the commitment.
    /// @dev bindingFactor should be used only once. Reusing bindingFactor results in the security
    ///      vulnerability.
    function reveal(
        uint8 playerIdx,
        Choice choice,
        bytes32 bindingFactor
    ) public onlyPlayerOfIdx(playerIdx) readyForRevealment(playerIdx) {
        // Choice.Secret is not allowed for the choice passed to the reveal function.
        require(
            choice != Choice.Secret,
            "Choice.Secret is not allowed when revealing."
        );

        // The pointer to the commit log of the player designated by playerIdx.
        Commitment storage commitment = commitLog[playerIdx];

        // Check the commit hash coincides with the one stored on chain.
        require(
            keccak256(abi.encodePacked(msg.sender, choice, bindingFactor)) ==
                commitment.commitString,
            "Commit hash doesn't coincide."
        );

        // Execute revealment
        commitment.choice = choice;

        // Emit the event that tells frontend that the player designated by playerIdx has revealed.
        emit Revealed(numRounds, playerIdx, choice);

        // Update the state of the reveal player to be Revealed.
        playerStates[playerIdx] = PlayerState.Revealed;
    }

    /// @notice Function to execute the battle.
    function battle() public onlyDealer readyForBattle {
        uint8 damage0 = _calcDamage(0);
        uint8 damage1 = _calcDamage(1);
        if (damage0 > damage1) {
            // player0 wins this round.
            winCount[0]++;
            emit BattleResult(numRounds, 0, 1, damage0, damage1);
            if (winCount[0] == WIN_COUNT) {
                // player0 wins this match.
                _settleBattle(0);
                emit BattleSettled(numRounds, 0, 1);
            }
        } else if (damage0 < damage1) {
            // player1 wins this round.
            winCount[1]++;
            emit BattleResult(numRounds, 1, 0, damage1, damage0);
            if (winCount[1] == WIN_COUNT) {
                // player1 wins this match.
                _settleBattle(1);
                emit BattleSettled(numRounds, 1, 0);
            }
        } else {
            emit BattleResultDraw(damage0);
        }
        numRound++;
        if (numRound == MAX_ROUND) {
            if (winCount[0] > winCount[1] {
                _settleBattle(0);
                emit BattleSettled(numRounds - 1, 0, 1, winCount[0], winCount[1]);
            } else if (winCount[0] < winCount[1]) {
                _settleBattle(1);
                emit BattleSettled(numRounds - 1, 1, 0, winCount[1], winCount[0]);
            } else {
                emit BattleSettledDraw(numRounds - 1, winCount[0]);
            }
        }
    }

    function _settleBattle(uint8 winnerIdx) internal onlyDealer readyForBattle payable {
        playerState[0] = PlayerState.RoundSettled;
        playerState[1] = PlayerState.RoundSettled;
        uint8 loserIdx = winnerIdx == 0? 1: 0;

        // Send MATIC from loser to winner.
        plmToken.transferFrom(playerAddress[loser], playerAddress[winnerIdx], amount);

        // Send MATIC from dealer to winner.
        plmToken.transferFrom(dealer, playerAddress[winnerIdx], amount);

    }

    /// @notice Function to calculate the damage of the monster.
    /// @param playerIdx: the index used to designate the player. 0 or 1.
    /// @return damage: damage of the character selected by the player designated by playerIdx in this round.
    function _calcDamage(uint8 playerIdx) internal returns (uint8 damage) {
        require(playerIdx == 0 || playerIdx == 1, "Invalid playerIdx.");

        Choice calldata choice = commitLog[playerIdx].choice;

        uint256 characterId;
        if (choice == Choice.Fixed1) {
            characterId = parties[playerIdx].fixedSlotId1;
        } else if (choice == Choice.Fixed2) {
            characterId = parties[playerIdx].fixedSlotId2;
        } else if (choice == Choice.Fixed3) {
            characterId = parties[playerIdx].fixedSlotId3;
        } else if (choice == Choice.Fixed4) {
            characterId = parties[playerIdx].fixedSlotId4;
        } else if (choice == Choice.Random1) {
            characterId = parties[playerIdx].randomSlotId1;
        } else if (choice == Choice.Random2) {
            characterId = parties[playerIdx].randomSlotId2;
        } else {
            revert("Unreachable !");
        }

        IPLMToken.characterInfo charInfo = PLMToken.getCharacterInfo(tokenId);

        // TODO: implement the damage logic later.
        return charInfo.level;
    }
}
