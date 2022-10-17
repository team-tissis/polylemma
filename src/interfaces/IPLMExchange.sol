interface IPLMExchange {
    event pooled(uint256 shareByUser, uint256 pooledValue);

    // TODO:
    // 送金したMATICと1；1でtransferがmint。mintされたPLMのうち一定割合がuserにtransfer
    // される。その割合は累進課税される。
    // _beforeMint: 税率の計算。課金額が高いほどtreasury
    // _afterMint: mintしたtoken自体は最初はtreasuryへ。そこから一定割合をユーザーへ
    function mintPLMByUser() external payable;

    function mintForTreasury(uint256 amount) external;
}
