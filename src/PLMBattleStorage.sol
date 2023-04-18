// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import {SSTORE2} from "lib/sstore2/contracts/SSTORE2.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";
import {Utils} from "./lib/Utils.sol";

contract PLMBattleStorage {
    /// @notice SSTORE2 pointer to the playerId referenced by battleId(uint256)
    mapping(uint256 => mapping(uint8=>address)) private pointerPlayerAddress;

    /// @notice SSTORE2 pointer to the numRounds referenced by battleId
    mapping(uint256 => address) private pointerNumRounds;

    /// @notice SSTORE2 pointer to the battleState referenced by battleId
    mapping(uint256 => address) private pointerBattleState;

    /// @notice SSTORE2 pointer to the round result referenced by battleId, indRound
    mapping(uint256 => mapping(uint256 => address)) private pointerRoundResults;

    /// @notice SSTORE2 pointer to the battle result referenced by battleId
    mapping(uint256 => address) private pointerBattleResult;

    /// @notice SSTORE2 pointer to the playerSeedCommitFromBlock referenced by battleId
    mapping(uint256 => address) private pointerPlayerSeedCommitFromBlock;

    /// @notice SSTORE2 pointer to the commitFromBlock referenced by battleId, indRound
    mapping(uint256 => mapping(uint8 => address))
        private pointerCommitFromBlocks;

    /// @notice SSTORE2 pointer to the revealFromBlock referenced by battleId, indRound
    mapping(uint256 => mapping(uint8 => address))
        private pointerRevealFromBlocks;

    /// @notice SSTORE2 pointer to the choiceCommit referenced by battleId, indRound, Player address
    mapping(uint256 => mapping(uint8 => mapping(address => address)))
        private pointerChoiceCommitLog;

    /// @notice SSTORE2 pointer to the playerSeedCommit referenced by battleId, Player address
    mapping(uint256 => mapping(address => address))
        private pointerPlayerSeedCommitLog;

    /// @notice SSTORE2 pointer to the playerInfo referenced by battleId, Player address
    mapping(uint256 => mapping(address => address))
        private pointerPlayerInfoTable;

    /// @notice enemy address referenced by playerAddress
    mapping(uint256 => mapping(address => address)) private pointerEnemyAddress;

    /// @notice BattleManager Contract's address
    address battleManager;

    /// @notice Deployer's address
    address polylemmer;

    modifier onlyBattleManager() {
        require(msg.sender == battleManager, "sender != managerContract");
        _;
    }

    constructor() {
        polylemmer = msg.sender;
    }

    ////////////////////////////////////////////////
    ///      Encoding/Decoding strucut, enum     ///
    ////////////////////////////////////////////////
    /**
     * Encoding, Decoding系はinternalとするべきだが，calldataを引数に取ることができるのが仕様上externalだけであり，
     * それぞれの関数で必須なbytesのスライスがcalldataにしか実装されていないため，externalで定義している．
     */

    function _encodeBattleState(
        IPLMBattleField.BattleState bs
    ) external pure returns (bytes memory) {
        return abi.encodePacked(uint256(bs));
    }

    function _encodeRoundResult(
        IPLMBattleField.RoundResult calldata rr
    ) external pure returns (bytes memory) {
        return
            abi.encodePacked(
                rr.isDraw,
                rr.winner,
                rr.loser,
                rr.winnerDamage,
                rr.loserDamage
            );
    }

    function _encodeBattleResult(
        IPLMBattleField.BattleResult calldata br
    ) external pure returns (bytes memory) {
        return
            abi.encodePacked(
                br.numRounds,
                br.isDraw,
                br.winner,
                br.loser,
                br.winnerCount,
                br.loserCount
            );
    }

    function _encodeChoiceCommit(
        IPLMBattleField.ChoiceCommit calldata cCommit
    ) external pure returns (bytes memory) {
        return
            abi.encodePacked(
                cCommit.commitString,
                cCommit.levelPoint,
                uint256(cCommit.choice)
            );
    }

    function _encodePlayerSeedCommit(
        IPLMBattleField.PlayerSeedCommit calldata psCommit
    ) external pure returns (bytes memory) {
        return abi.encodePacked(psCommit.commitString, psCommit.playerSeed);
    }

    function _encodePlayerInfo(
        IPLMBattleField.PlayerInfo calldata playerInfo
    ) external pure returns (bytes memory) {
        bytes memory randomSlotEncoded = abi.encodePacked(
            playerInfo.randomSlot.level, // 1byte
            playerInfo.randomSlot.nonce, // 32bytes
            playerInfo.randomSlot.usedRound, //1byte
            uint256(playerInfo.randomSlot.state) // 32bytes
        );
        return
            abi.encodePacked(
                playerInfo.addr, //20bytes
                playerInfo.fromBlock, //32bytes
                playerInfo.fixedSlots, // [4] 32bytes
                playerInfo.fixedSlotsUsedRounds, // [4] 1byte
                randomSlotEncoded, //
                uint256(playerInfo.state),
                playerInfo.winCount,
                playerInfo.maxLevelPoint,
                playerInfo.remainingLevelPoint
            );
    }

    function _encodeEnemyAddress(
        address enemy
    ) external pure returns (bytes memory) {
        return abi.encodePacked(enemy);
    }

    function _decodeBattleState(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.BattleState) {
        return IPLMBattleField.BattleState(Utils.bytesToUint(encoded));
    }

    function _decodeRoundResult(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.RoundResult memory) {
        // RoundResult members: bool, address, address, uint32, uint32
        return
            IPLMBattleField.RoundResult({
                isDraw: Utils.bytesToBool(encoded[0:1]),
                winner: Utils.bytesToAddress(encoded[1:21]),
                loser: Utils.bytesToAddress(encoded[21:41]),
                winnerDamage: uint32(Utils.bytesToUint(encoded[41:45])),
                loserDamage: uint32(Utils.bytesToUint(encoded[45:49]))
            });
    }

    function _decodeBattleResult(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.BattleResult memory) {
        return
            IPLMBattleField.BattleResult({
                numRounds: uint8(Utils.bytesToUint(encoded[0:1])),
                isDraw: Utils.bytesToBool(encoded[1:2]),
                winner: Utils.bytesToAddress(encoded[2:22]),
                loser: Utils.bytesToAddress(encoded[22:42]),
                winnerCount: uint8(Utils.bytesToUint(encoded[42:43])),
                loserCount: uint8(Utils.bytesToUint(encoded[43:44]))
            });
    }

    function _decodeChoiceCommit(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.ChoiceCommit memory) {
        return
            IPLMBattleField.ChoiceCommit({
                commitString: bytes32(encoded[0:32]),
                levelPoint: uint8(Utils.bytesToUint(encoded[32:33])),
                choice: IPLMBattleField.Choice(
                    Utils.bytesToUint(encoded[33:65])
                )
            });
    }

    function _decodePlayerSeedCommit(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.PlayerSeedCommit memory) {
        return
            IPLMBattleField.PlayerSeedCommit({
                commitString: bytes32(encoded[0:32]),
                playerSeed: bytes32(encoded[32:64])
            });
    }

    function _decodePlayerInfo(
        bytes calldata encoded
    ) external pure returns (IPLMBattleField.PlayerInfo memory) {
        return
            IPLMBattleField.PlayerInfo({
                addr: Utils.bytesToAddress(encoded[0:20]),
                fromBlock: Utils.bytesToUint(encoded[20:52]),
                fixedSlots: [
                    Utils.bytesToUint(encoded[52:84]),
                    Utils.bytesToUint(encoded[84:116]),
                    Utils.bytesToUint(encoded[116:148]),
                    Utils.bytesToUint(encoded[148:180])
                ],
                fixedSlotsUsedRounds: [
                    uint8(Utils.bytesToUint(encoded[180:212])),
                    uint8(Utils.bytesToUint(encoded[212:244])),
                    uint8(Utils.bytesToUint(encoded[244:276])),
                    uint8(Utils.bytesToUint(encoded[276:308]))
                ],
                randomSlot: IPLMBattleField.RandomSlot({
                    level: uint8(Utils.bytesToUint(encoded[308:309])),
                    nonce: bytes32(encoded[309:341]),
                    usedRound: uint8(Utils.bytesToUint(encoded[341:342])),
                    state: IPLMBattleField.RandomSlotState(
                        Utils.bytesToUint(encoded[342:374])
                    )
                }),
                state: IPLMBattleField.PlayerState(
                    Utils.bytesToUint(encoded[374:406])
                ),
                winCount: uint8(Utils.bytesToUint(encoded[406:407])),
                maxLevelPoint: uint8(Utils.bytesToUint(encoded[407:408])),
                remainingLevelPoint: uint8(Utils.bytesToUint(encoded[408:409]))
            });
    }

    function _decodeAddress(
        bytes calldata encoded
    ) external pure returns (address) {
        return Utils.bytesToAddress(encoded[0:20]);
    }

    //////////////////////////////////
    ///      Writer/Loader         ///
    //////////////////////////////////
    /// @notice store numRounds by SSTORE2. It is read only, so overwrite all data when updating.
    function writePlayerAddressByPlayerId(
        uint256 battleId,
        address homeAddress,
        address visitorAddress
    ) external onlyBattleManager {
        // homeAddress
        pointerPlayerAddress[battleId][0] = SSTORE2.write(abi.encodePacked(homeAddress));
        // visitorAddress
        pointerPlayerAddress[battleId][1] = SSTORE2.write(abi.encodePacked(visitorAddress));
    }
    
    /// @notice store numRounds by SSTORE2. It is read only, so overwrite all data when updating.
    function writeNumRounds(
        uint256 battleId,
        uint256 numRounds
    ) external onlyBattleManager {
        pointerNumRounds[battleId] = SSTORE2.write(abi.encodePacked(numRounds));
    }

    /// @notice store battleState by SSTORE2. It is read only, so overwrite all data when updating.
    function writeBattleState(
        uint256 battleId,
        IPLMBattleField.BattleState battleState
    ) external onlyBattleManager {
        pointerBattleState[battleId] = SSTORE2.write(
            this._encodeBattleState(battleState)
        );
    }

    /// @notice store roundResult by SSTORE2. It is read only, so overwrite all data when updating.
    function writeRoundResult(
        uint256 battleId,
        uint256 indRound,
        IPLMBattleField.RoundResult calldata roundResult
    ) external onlyBattleManager {
        pointerRoundResults[battleId][indRound] = SSTORE2.write(
            this._encodeRoundResult(roundResult)
        );
    }

    /// @notice store battleResult by SSTORE2. It is read only, so overwrite all data when updating.
    function writeBattleResult(
        uint256 battleId,
        IPLMBattleField.BattleResult calldata battleResult
    ) external onlyBattleManager {
        pointerBattleResult[battleId] = SSTORE2.write(
            this._encodeBattleResult(battleResult)
        );
    }

    /// @notice store playerSeedCommitFromBlock  by SSTORE2. It is read only, so overwrite all data when updating.
    function writePlayerSeedCommitFromBlock(
        uint256 battleId,
        uint256 playerSeedCommitFromBlock
    ) external onlyBattleManager {
        pointerPlayerSeedCommitFromBlock[battleId] = SSTORE2.write(
            abi.encodePacked(playerSeedCommitFromBlock)
        );
    }

    /// @notice store CommitFromBlock by SSTORE2. It is read only, so overwrite all data when updating.
    function writeCommitFromBlock(
        uint256 battleId,
        uint8 indRound,
        uint256 commitFromBlock
    ) external onlyBattleManager {
        pointerCommitFromBlocks[battleId][indRound] = SSTORE2.write(
            abi.encodePacked(commitFromBlock)
        );
    }

    /// @notice store revealFromBlock  by SSTORE2. It is read only, so overwrite all data when updating.
    function writeRevealFromBlock(
        uint256 battleId,
        uint8 indRound,
        uint256 revealFromBlock
    ) external onlyBattleManager {
        pointerRevealFromBlocks[battleId][indRound] = SSTORE2.write(
            abi.encodePacked(revealFromBlock)
        );
    }

    /// @notice store ChoiceCommit by SSTORE2. It is read only, so overwrite all data when updating.
    function writeChoiceCommitLog(
        uint256 battleId,
        uint8 indRound,
        address player,
        IPLMBattleField.ChoiceCommit calldata choiceCommit
    ) external onlyBattleManager {
        pointerChoiceCommitLog[battleId][indRound][player] = SSTORE2.write(
            this._encodeChoiceCommit(choiceCommit)
        );
    }

    /// @notice store PlayerSeedCommit by SSTORE2. It is read only, so overwrite all data when updating.
    function writePlayerSeedCommitLog(
        uint256 battleId,
        address player,
        IPLMBattleField.PlayerSeedCommit calldata playerSeedCommit
    ) external onlyBattleManager {
        pointerPlayerSeedCommitLog[battleId][player] = SSTORE2.write(
            this._encodePlayerSeedCommit(playerSeedCommit)
        );
    }

    /// @notice store PlayerInfo by SSTORE2. It is read only, so overwrite all data when updating.
    function writePlayerInfoTable(
        uint256 battleId,
        address player,
        IPLMBattleField.PlayerInfo calldata playerInfo
    ) external onlyBattleManager {
        pointerPlayerInfoTable[battleId][player] = SSTORE2.write(
            this._encodePlayerInfo(playerInfo)
        );
    }

    /// @notice store enemyAddress by SSTORE2. It is read only, so overwrite all data when updating.
    function writeEnemyAddress(
        uint256 battleId,
        address player,
        address enemy
    ) external onlyBattleManager {
        pointerEnemyAddress[battleId][player] = SSTORE2.write(
            this._encodeEnemyAddress(enemy)
        );
    }

    /// @notice load playerId by SSTORE2.
    function loadPlayerId(uint256 battleId, address player) external view returns(uint8) {
        // load homeAddress
        bytes memory loadedHome = SSTORE2.read(pointerPlayerAddress[battleId][0]);
        bytes memory loadedVisitor = SSTORE2.read(pointerPlayerAddress[battleId][1]);
        if (keccak256(abi.encodePacked((this._decodeAddress(loadedHome)))) == keccak256(abi.encodePacked(player))) {
            return 0;
        } else if (keccak256(abi.encodePacked(this._decodeAddress(loadedVisitor))) == keccak256(abi.encodePacked(player))) {
            return 1;
        } else {
            revert("Error: this address is not a player of the battle.");
        }
    }

    /// @notice load playerId by SSTORE2.
    function loadPlayerAddressById(uint256 battleId, uint8 playerId) external view returns(address) {
        // load homeAddress
        bytes memory loaded = SSTORE2.read(pointerPlayerAddress[battleId][playerId]);
        return this._decodeAddress(loaded);
    }
    

    /// @notice load NumRounds by SSTORE2.
    function loadNumRounds(uint256 battleId) external view returns (uint8) {
        bytes memory loaded = SSTORE2.read(pointerNumRounds[battleId]);
        return uint8(Utils.bytesToUint(loaded));
    }

    /// @notice load BattleState by SSTORE2.
    function loadBattleState(
        uint256 battleId
    ) external view returns (IPLMBattleField.BattleState) {
        bytes memory loaded = SSTORE2.read(pointerBattleState[battleId]);
        return this._decodeBattleState(loaded);
    }

    /// @notice load Roundresults by SSTORE2.
    function loadRoundResults(
        uint256 battleId,
        uint8 indRound
    ) external view returns (IPLMBattleField.RoundResult memory) {
        bytes memory loaded = SSTORE2.read(
            pointerRoundResults[battleId][indRound]
        );
        return this._decodeRoundResult(loaded);
    }

    /// @notice load BattleResults by SSTORE2.
    function loadBattleResult(
        uint256 battleId
    ) external view returns (IPLMBattleField.BattleResult memory) {
        bytes memory loaded = SSTORE2.read(pointerBattleResult[battleId]);
        return this._decodeBattleResult(loaded);
    }

    /// @notice load PlayerSeedCommitFromBlock by SSTORE2.
    function loadPlayerSeedCommitFromBlock(
        uint256 battleId
    ) external view returns (uint256) {
        bytes memory loaded = SSTORE2.read(
            pointerPlayerSeedCommitFromBlock[battleId]
        );
        return Utils.bytesToUint(loaded);
    }

    /// @notice load CommitFromBlock by SSTORE2.
    function loadCommitFromBlocks(
        uint256 battleId,
        uint8 indRound
    ) external view returns (uint256) {
        bytes memory loaded = SSTORE2.read(
            pointerCommitFromBlocks[battleId][indRound]
        );
        return Utils.bytesToUint(loaded);
    }

    /// @notice load RevealFromBlock by SSTORE2.
    function loadRevealFromBlocks(
        uint256 battleId,
        uint8 indRound
    ) external view returns (uint256) {
        bytes memory loaded = SSTORE2.read(
            pointerRevealFromBlocks[battleId][indRound]
        );
        return Utils.bytesToUint(loaded);
    }

    /// @notice load ChoiceCommit by SSTORE2.
    function loadChoiceCommitLog(
        uint256 battleId,
        uint8 indRound,
        address player
    ) external view returns (IPLMBattleField.ChoiceCommit memory) {
        bytes memory loaded = SSTORE2.read(
            pointerChoiceCommitLog[battleId][indRound][player]
        );
        return this._decodeChoiceCommit(loaded);
    }

    /// @notice load PlayerSeedCommit by SSTORE2.
    function loadPlayerSeedCommitLog(
        uint256 battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerSeedCommit memory) {
        bytes memory loaded = SSTORE2.read(
            pointerPlayerSeedCommitLog[battleId][player]
        );
        return this._decodePlayerSeedCommit(loaded);
    }

    /// @notice load PlayerInfo by SSTORE2.
    function loadPlayerInfoTable(
        uint256 battleId,
        address player
    ) external view returns (IPLMBattleField.PlayerInfo memory) {
        bytes memory loaded = SSTORE2.read(
            pointerPlayerInfoTable[battleId][player]
        );
        return this._decodePlayerInfo(loaded);
    }

    /// @notice load BattleState by SSTORE2.
    function loadEnemyAddress(
        uint256 battleId,
        address player
    ) external view returns (address) {
        bytes memory loaded = SSTORE2.read(
            pointerEnemyAddress[battleId][player]
        );
        return this._decodeAddress(loaded);
    }

    ////////////////////////////
    ////   set permission   ////
    ////////////////////////////
    function setBattleManager(address _battleManager) external {
        require(msg.sender == polylemmer);
        battleManager = _battleManager;
    }
}
