interface IPLMGacha {
    event CharacterRecievedByUser(uint256 indexed tokenId);

    function gacha() external returns (uint256);
}
