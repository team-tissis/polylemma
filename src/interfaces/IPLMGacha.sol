import {IPLMToken} from "./IPLMToken.sol";

interface IPLMGacha {
    ////////////////////////
    ///      EVENTS      ///
    ////////////////////////

    event CharacterReceivedByUser(
        address indexed account,
        uint256 tokenId,
        IPLMToken.CharacterInfo characterInfo
    );

    ////////////////////////
    ///      ERRORS      ///
    ////////////////////////

    error ErrorWithLog(string reason);

    /////////////////////////
    ///  GACHA FUNCTIONS  ///
    /////////////////////////

    function gacha(bytes32[] calldata names, uint256 num) external;

    /////////////////////////
    ///      GETTERS      ///
    /////////////////////////

    function getGachaFee() external pure returns (uint256);
}
