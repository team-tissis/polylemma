import {IPlmToken} from "./interfaces/IPlmToken.sol";
import {IPlmCoin} from "./interfaces/IPlmCoin.sol";
import {IPlmGacha} from "./interfaces/IPlmGacha.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract PlmGacha is IPlmGacha, ReentracncyGuard {
    IPlmToken public plmToken;
    IPlmCoin public plmCoin;

    address gameMaster;

    uint256 gachaPayment;

    modifier onlyGameMaster() {
        require(msg.sender == gameMaster, "this address is not game master.");
        _;
    }

    constructor(
        IPlmToken _plmToken,
        IPlmData _plmCoin,
        uint256 _gachaPayment
    ) {
        plmToken = _plmToken;
        plmCoin = _plmCoin;
        gachaPayment = _gachaPayment;
    }

    function gacha() external nonReentrant {
        // require(plmCoin.balanceOf(msg.sender)<);
        try plmToken.mint() returns (uint256 tokenId) {
            emit CharacterRecievedByUser(tokenId);
        } catch Error(string memory) {
            _pause();
        }
    }

    function setGachaPayment(uint256 _newGachaPayment) internal onlyGameMaster {
        gachaPayment = _newGachaPayment;
    }
}
