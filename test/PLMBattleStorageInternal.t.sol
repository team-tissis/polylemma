// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {Utils} from "../src/lib/Utils.sol";
import {PLMBattleStorage} from "../src/PLMBattleStorage.sol";
import {IPLMBattleField} from "../src/interfaces/IPLMBattleField.sol";

contract BattleStorageInternal is Test, PLMBattleStorage {
    function setUp() public {}

    function testEncodeBattleState() public {
        IPLMBattleField.BattleState bs = IPLMBattleField.BattleState.Canceled;
        bytes memory encoded = this._encodeBattleState(bs);
        // uint256 decoded = Utils.bytesToUint256(encoded);
        uint256 decoded = uint256(bytes32(encoded));
        assertEq(uint256(bs), decoded);
    }

    function testEncodeRoundResult() public {
        IPLMBattleField.RoundResult memory rr = IPLMBattleField.RoundResult({
            isDraw: false,
            winner: address(22),
            loser: address(23),
            winnerDamage: 10,
            loserDamage: 6
        });
        bytes memory encoded = this._encodeRoundResult(rr);
        IPLMBattleField.RoundResult memory decoded = this._decodeRoundResult(
            encoded
        );
        assertEq(
            encoded,
            this._encodeRoundResult(decoded),
            "not decoded properly"
        );
    }

    function testEncodeBattleResult() public {
        IPLMBattleField.BattleResult memory br = IPLMBattleField.BattleResult({
            numRounds: 4,
            isDraw: false,
            winner: address(22),
            loser: address(23),
            winnerCount: 10,
            loserCount: 6
        });
        bytes memory encoded = this._encodeBattleResult(br);
        IPLMBattleField.BattleResult memory decoded = this._decodeBattleResult(
            encoded
        );
        assertEq(
            encoded,
            this._encodeBattleResult(decoded),
            "not decoded properly"
        );
    }

    function testEncodeCommitChoice() public {
        IPLMBattleField.ChoiceCommit memory cc = IPLMBattleField.ChoiceCommit({
            commitString: "sdasodhwkdfjkhdjkflhjh",
            levelPoint: 19,
            choice: IPLMBattleField.Choice.Fixed3
        });
        bytes memory encoded = this._encodeChoiceCommit(cc);
        IPLMBattleField.ChoiceCommit memory decoded = this._decodeChoiceCommit(
            encoded
        );
        assertEq(
            encoded,
            this._encodeChoiceCommit(decoded),
            "not decoded properly"
        );
    }

    function testEncodePlayerSeedCommit() public {
        IPLMBattleField.PlayerSeedCommit memory psc = IPLMBattleField
            .PlayerSeedCommit({
                commitString: "asdasjlkfhdwjkfh",
                playerSeed: "djlkfhohovwfoe12138924hfdh"
            });
        bytes memory encoded = this._encodePlayerSeedCommit(psc);
        IPLMBattleField.PlayerSeedCommit memory decoded = this
            ._decodePlayerSeedCommit(encoded);
        assertEq(
            encoded,
            this._encodePlayerSeedCommit(decoded),
            "not decoded properly"
        );
    }

    function testEncodePlayerInfo() public {
        IPLMBattleField.PlayerInfo memory pi = IPLMBattleField.PlayerInfo({
            addr: address(12072),
            fromBlock: 10,
            fixedSlots: [uint256(1), 9, 21, 32],
            fixedSlotsUsedRounds: [uint8(2), 1, 4, 3],
            randomSlot: IPLMBattleField.RandomSlot({
                level: 28,
                nonce: 0x3234333478636473666473000000000000000000000000000000000000000000,
                usedRound: 3,
                state: IPLMBattleField.RandomSlotState.Revealed
            }),
            state: IPLMBattleField.PlayerState.Standby,
            winCount: 1,
            maxLevelPoint: 10,
            remainingLevelPoint: 23
        });
        bytes memory encoded = this._encodePlayerInfo(pi);
        IPLMBattleField.PlayerInfo memory decoded = this._decodePlayerInfo(
            encoded
        );
        assertEq(
            encoded,
            this._encodePlayerInfo(decoded),
            "not decoded properly"
        );
    }
}
