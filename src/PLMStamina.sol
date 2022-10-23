pragma solidity 0.8.17;

contract PLMStamina {
    // player's address to blockNumber when it is restored
    mapping(address => uint256) staminaMax;
    mapping(address => uint256) blockNumberForStamina;

    uint8 restoreSpeed;
    uint8 initialStaminaMax;
    uint8 staminaForABattle;

    constructor(uint8 _initialStaminaMax) {
        initialStaminaMax = _initialStaminaMax;
    }

    function initializeStamina(address player, uint8 _restoreSpeed) public {
        staminaMax[player] = initialStaminaMax;
        blockNumberForStamina[player] = block.number;
        restoreSpeed = _restoreSpeed;
    }

    function getCurrentStamina(address player) public view returns (uint256) {
        return (block.number - blockNumberForStamina[player]) * restoreSpeed;
    }

    function getStaminaMax(address player) public view returns (uint256) {
        return staminaMax[player];
    }

    function restoreFullStamina(address player) public {
        blockNumberForStamina[player] =
            block.number -
            staminaMax[player] /
            restoreSpeed;
    }

    function consumeStaminaForBattle(address player) public {
        blockNumberForStamina[player] += staminaForABattle;
    }
}
