import {IPLMToken} from "./interfaces/IPLMToken.sol";

interface IPLMGacha {
    event CharacterRecievedByUser(
        uint256 indexed tokenId,
        IPLMToken.CharacterInfo indexed characterInfo
    );

    function gacha() external returns (uint256);
}
