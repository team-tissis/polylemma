import {IPolylemmaToken} from "./interfaces/IPolylemmaToken.sol";
import {IPolylemmaPLM} from "./interfaces/IPolylemmaPLM.sol";
import {IPolylemmaGacha} from "./interfaces/IPolylemmaGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract PolylemmaGacha is IPolylemmaGacha, ReentracncyGuard {
    IPolylemmaToken public polylemmaToken;
    IPolylemmaPLM public polylemmaPLM;

    address gameMaster;

    uint256 gachaPayment;

    modifier onlyGameMaster() {
        require(msg.sender == gameMaster, "this address is not game master.");
        _;
    }

    constructor(
        IPolylemmaToken _polylemmaToken,
        IPolylemmaData _polylemmaPLM,
        uint256 _gachaPayment
    ) {
        polylemmaToken = _polylemmaToken;
        polylemmaPLM = _polylemmaPLM;
        gachaPayment = _gachaPayment;
    }

    function gacha() external nonReentrant {
        require(polylemmaPLM.balanceOf(msg.sender)<);
        try polylemmaToken.mint() returns (uint256 tokenId) {
            emit CharacterRecievedByUser(tokenId);
        } catch Error(string memory) {
            _pause();
        }
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyGameMaster {
        gachaPayment = _newGachaPayment;
    }
}
