interface IPolylemmaGacha {
    event CharacterRecievedByUser(uint256 indexed tokenId);

    function gacha() external;
}
