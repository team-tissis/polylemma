import {IPLMToken} from "./IPLMToken.sol";

interface IPLMGacha {
    event CharacterReceivedByUser(
        address indexed account,
        uint256 tokenId,
        IPLMToken.CharacterInfo characterInfo
    );

    error ErrorWithLog(string reason);

    function getGachaFee() external pure returns (uint256);

    function gacha(bytes20 name) external;
}
