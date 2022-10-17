import {IPLMToken} from "./IPLMToken.sol";

interface IPLMGacha {
    event CharacterRecievedByUser(
        address indexed account,
        uint256 tokenId,
        IPLMToken.CharacterInfo characterInfo
    );

    function getDealer() external view returns (address);

    function getGachaPayment() external view returns (uint256);

    function gacha() external;
}
