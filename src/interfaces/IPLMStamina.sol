interface IPLMStamina {
    function getCurrentStamina(address player) external view returns (uint256);

    function getStaminaMax(address player) external view returns (uint256);

    function restoreFullStamina(address player) external;

    function consumeStaminaForBattle(address player) external;
}
