import {Math} from "openzeppelin-contracts/utils/math/math.sol";
import {SafeMath} from "openzeppelin-contracts/utils/math/SafeMath.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMEx} from "./interfaces/IPLMEx.sol";

contract PLMEx is IPLMEx {
    using Math for uint256;
    using SafeMath for uint256;
    address dealer;
    address treasury;
    uint256 maticAmount;
    IPLMData data;
    IPLMCoin coin;

    constructor(IPLMData _data, IPLMCoin _coin) {
        dealer = msg.sender;
        data = _data;
        coin = _coin;
        treasury = address(this);
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "sender is not this contract's owner.");
        _;
    }

    //MATICに対して1:1でmintする (叩くのはUser)
    function mintPLMByUser() public payable {
        // TODO: restriction of user minting
        maticAmount += msg.value;
        coin.mint(msg.value);
        _transferPLMWithPooling(msg.sender, msg.value);
    }

    // TODO: 現行の実装では、少ない課金の時に大半をプールされてしまう。これは累進課税を_calcPoolingFromMintに実装することで解決する。
    function _transferPLMWithPooling(address account, uint256 amount) internal {
        // mint PLM as much as payment of MATIC
        // calc how much treasury pool minted coin
        uint256 pool = _calcPoolingFromMint(amount);
        // amount - _calcPoolingFromMint(amount);
        emit pooled(amount - pool, pool);
        coin.transfer(account, amount - pool);
    }

    /// @return how much PLM be pooled by treasury
    function _calcPoolingFromMint(uint256 mintedVolume)
        internal
        view
        returns (uint256)
    {
        uint256 tax;
        uint256 taxTotal;
        (tax, taxTotal) = data.getTaxRate(mintedVolume);
        return (mintedVolume * tax).mod(taxTotal);
    }

    function withdraw(uint256 amount) public onlyDealer {
        require(amount <= maticAmount, "cannot withdraw over value");
        payable(dealer).transfer(amount);
    }

    function mintForTreasury(uint256 amount) public onlyDealer {
        coin.mint(amount);
    }
}
