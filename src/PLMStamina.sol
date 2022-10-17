pragma solidity 0.8.17;

contract PLMStamina {
    // player's address to blockNumber when it is restored
    mapping(address => uint256) staminaMax;
    mapping(address => uint256) staminaZeroPoints;

    uint8 constant restoreSpeed = 5;
    uint8 constant initialStaminaMax = 100;
    uint8 constant staminaPerBattle = 10;

    constructor(uint8 _initialStaminaMax) {
        // initialStaminaMax = _initialStaminaMax;
    }

    function initializeStamina(address player, uint8 _restoreSpeed) public {
        staminaMax[player] = initialStaminaMax;
        staminaZeroPoints[player] = block.number;
        // restoreSpeed = _restoreSpeed;
    }

    function getCurrentStamina(address player) public view returns (uint256) {
        return (block.number - staminaZeroPoints[player]) * restoreSpeed;
    }

    function getStaminaMax(address player) public view returns (uint256) {
        return staminaMax[player];
    }

    function restoreFullStamina(address player) public {
        staminaZeroPoints[player] =
            block.number -
            staminaMax[player] /
            restoreSpeed;
    }

    function consumeStaminaForBattle(address player) public {
        staminaZeroPoints[player] += staminaPerBattle;
    }
}
