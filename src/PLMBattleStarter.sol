

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;


import {PLMBattleField} from "./PLMBattleField.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMBattleManager} from "./interfaces/IPLMBattleManager.sol";
import {IPLMDealer} from "./interfaces/IPLMDealer.sol";
import {IPLMBattleStarter} from "./interfaces/IPLMBattleStarter.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMBattleField} from "./interfaces/IPLMBattleField.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

contract PLMBattleStarter is PLMBattleField, IPLMBattleStarter {

    modifier onlyMatchOrganizer() {
        require(
            msg.sender == address(matchOrganizer),
            "sender != matchOrganizer"
        );
        _;
    }

    constructor(
        IPLMDealer _dealer,
        IPLMToken _token,
        IPLMBattleManager _manager
    ) PLMBattleField(_dealer,_token, _manager) {
    }
        /// @notice Function to start the battle.
    /// @dev This function is called from match organizer.
    /// @param homeAddr: the address of the player assigned to home.
    /// @param visitorAddr: the address of the player assigned to visitor.
    /// @param homeFromBlock: the block number used to view home's characters' info.
    /// @param visitorFromBlock: the block number used to view visitor's characters' info.
    /// @param homeFixedSlots: tokenIds of home's fixed slots.
    /// @param visitorFixedSlots: tokenIds of visitor's fixed slots.
    function startBattle(
        address homeAddr,
        address visitorAddr,
        uint256 homeFromBlock,
        uint256 visitorFromBlock,
        uint256[4] memory homeFixedSlots,
        uint256[4] memory visitorFixedSlots
    ) external onlyMatchOrganizer {
        manager.beforeBattleStart(homeAddr, visitorAddr);
        
        IPLMData.CharacterInfoMinimal[FIXED_SLOTS_NUM] memory homeCharInfos; IPLMData.CharacterInfoMinimal[FIXED_SLOTS_NUM] memory visitorCharInfos;
        // Retrieve character infomation by tokenId in the fixed slots.
        for (uint8 slotIdx = 0; slotIdx < FIXED_SLOTS_NUM; slotIdx++) {
            homeCharInfos[slotIdx] = token.minimalizeCharInfo(
                token.getPriorCharacterInfo(
                    homeFixedSlots[slotIdx],
                    homeFromBlock
                )
            );
            visitorCharInfos[slotIdx] = token.minimalizeCharInfo(
                token.getPriorCharacterInfo(
                    visitorFixedSlots[slotIdx],
                    visitorFromBlock
                )
            );
        }

        {
            // Get level point for both players.
            uint8 homeLevelPoint = data.getLevelPoint(homeCharInfos);

            // Initialize both players' information.
            // Initialize random slots of them too.
            manager.setPlayerInfo(
                homeAddr,
                PlayerInfo(
                    homeAddr,
                    homeFromBlock,
                    homeFixedSlots,
                    [0, 0, 0, 0],
                    RandomSlot(
                        data.getRandomSlotLevel(homeCharInfos),
                        bytes32(0),
                        0,
                        RandomSlotState.NotSet
                    ),
                    PlayerState.Standby,
                    0,
                    homeLevelPoint,
                    homeLevelPoint
                )
            );
        }
        {
            uint8 visitorLevelPoint = data.getLevelPoint(visitorCharInfos);
            manager.setPlayerInfo(
                visitorAddr,
                PlayerInfo(
                    visitorAddr,
                    visitorFromBlock,
                    visitorFixedSlots,
                    [0, 0, 0, 0],
                    RandomSlot(
                        data.getRandomSlotLevel(visitorCharInfos),
                        bytes32(0),
                        0,
                        RandomSlotState.NotSet
                    ),
                    PlayerState.Standby,
                    0,
                    visitorLevelPoint,
                    visitorLevelPoint
                )
            );
        }

        // Change battle state to wait for the playerSeed commitment.
        manager.setBattleState(homeAddr, BattleState.Standby);

        // Set the block number when the battle has started.
        manager.setPlayerSeedCommitFromBlock(homeAddr, block.number);

        // Reset round number.
        manager.setNumRounds(homeAddr, 0);

        emit BattleStarted(_battleId(), homeAddr, visitorAddr);
    }

    // FIXME: 仮置き
    function getFixedSlotsCharInfo(uint8 playerId)
        external
        view
        returns (IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory)
    {   
        address player = manager.getPlayerAddressById(manager.getLatestBattle(msg.sender),playerId);
        IPLMToken.CharacterInfo[FIXED_SLOTS_NUM] memory playerCharInfos;
        for (uint8 i = 0; i < FIXED_SLOTS_NUM; i++) {
            playerCharInfos[i] = _fixedSlotCharInfoByIdx(player, i);
        }

        return playerCharInfos;
    }

    // FIXME:仮おき
    function getRandomSlotCharInfo(
        address player
    ) external view returns (IPLMToken.CharacterInfo memory) {
        return _randomSlotCharInfo(player);
    }


    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IPLMBattleField).interfaceId ||
            interfaceId == type(IPLMBattleStarter).interfaceId;
    }



        // FIXME: remove this function after demo.
    function forceInitBattle() external {
        manager.setBattleState(msg.sender, BattleState.Settled);
        matchOrganizer.forceResetMatchState(msg.sender);
        matchOrganizer.forceResetMatchState(_enemyAddress());
        uint256 _battleId = _battleId();
        emit BattleCanceled(_battleId);
        emit ForceInited(_battleId);
    }

}
