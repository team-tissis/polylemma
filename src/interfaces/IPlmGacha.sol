interface IPlmGacha {
    event CharacterRecievedByUser(uint256 indexed tokenId);

    function gacha() external;
}
