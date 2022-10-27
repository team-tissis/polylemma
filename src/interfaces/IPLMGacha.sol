import {IPLMToken} from "./IPLMToken.sol";

interface IPLMGacha {
    event CharacterRecievedByUser(
        uint256 indexed tokenId,
        IPLMToken.CharacterInfo indexed characterInfo
    );

    function getDealer() external view returns (address);

    function getGachaPayment() external view returns (uint256);

    function gacha() external;
}
