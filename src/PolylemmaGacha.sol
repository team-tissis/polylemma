import {IPolylemmaData} from "./interfaces/IpolylemmaData.sol";
import {IPolylemmaToken} from "./interfaces/IpolylemmaToken.sol";
import {IPolylemmaGacha} from "./interfaces/IPolylemmaGacha.sol";

contract PolylemmaGacha is IPolylemmaGacha {
    IPolylemmaToken public polylemmaToken;
    IPolylemmaData public polylemmaData;

    constructor(IPolylemmaData _polylemmaData, IPolylemmaToken _polylemmaToken)
    {
        polylemmaData = _polylemmaData;
        polylemmaToken = _polylemmaToken;
    }

    function gacha() internal {
        try polylemmaToken.mint() returns (uint256 tokenId) {
            emit CharacterRecievedByUser(tokenId);
        } catch Error(string memory) {
            _pause();
        }
    }
}
