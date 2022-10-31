// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {PLMSeeder} from "./lib/PLMSeeder.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {PLMData} from "./subcontracts/PLMData.sol";

import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";

contract PLMToken is ERC721Enumerable, PLMData, IPLMToken, ReentrancyGuard {
    using Counters for Counters.Counter;

    address polylemmer;
    address dealer;
    address enhancer;
    uint256 maxSupply;
    IPLMCoin coin;

    uint256 private currentTokenId = 0;

    /// @notice A record of charInfo checkpoints for each account, by index.
    /// @dev The key of this map is tokenId.
    mapping(uint256 => mapping(uint32 => Checkpoint)) checkpoints;

    /// @notice The number of checkpoints for each token
    mapping(uint256 => uint32) public numCheckpoints;

    modifier onlyPolylemmer() {
        require(
            msg.sender == polylemmer,
            "Permission denied. Sender is not polylemmer."
        );
        _;
    }

    modifier onlyDealer() {
        require(
            msg.sender == dealer,
            "Permission denied. Sender is not dealer."
        );
        _;
    }

    constructor(
        address _dealer,
        IPLMCoin _coin,
        uint256 _maxSupply
    ) ERC721("Polylemma", "PLM") {
        polylemmer = msg.sender;
        dealer = _dealer;
        coin = _coin;
        maxSupply = _maxSupply;
    }

    // dealerにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint(bytes32 name) public onlyDealer returns (uint256) {
        currentTokenId++;
        return _mintTo(dealer, currentTokenId, name);
    }

    // TODO: Is burn func. required?
    // If some reasons arise to impl it, yes, it is.
    function burn(uint256 tokenId) public onlyDealer {
        _burn(tokenId);
    }

    function getAllTokenOwned(address account)
        public
        view
        returns (uint256[] memory)
    {
        uint256 balanceOfTokens = ERC721.balanceOf(account);
        uint256[] memory allTokensOwned = new uint256[](balanceOfTokens);
        for (uint256 i = 0; i < balanceOfTokens; i++) {
            allTokensOwned[i] = ERC721Enumerable.tokenOfOwnerByIndex(
                msg.sender,
                i
            );
        }
        return allTokensOwned;
    }

    // TODO: for文回してるのでガス代くそかかる。節約した記述を考える
    function getAllCharacterInfo()
        public
        view
        override
        returns (CharacterInfo[] memory)
    {
        CharacterInfo[] memory allCharacterInfos = new CharacterInfo[](
            currentTokenId
        );
        for (uint256 i = 0; i < currentTokenId; i++) {
            // tokenIdは one-based, 配列のindexはzero-based
            allCharacterInfos[i] = getCurrentCharacterInfo(i + 1);
        }
        return allCharacterInfos;
    }

    function getElapsedFromBlock(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return block.number - getCurrentCharacterInfo(tokenId).fromBlock;
    }

    /// @notice increment level with consuming his coin
    function updateLevel(uint256 tokenId) external nonReentrant {
        require(
            msg.sender == ownerOf(tokenId),
            "Permission denied. Sender is not owner of this token"
        );
        require(getCurrentCharacterInfo(tokenId).level <= 255, "level is max.");

        uint256 necessaryExp = getNecessaryExp(tokenId);
        // whether user have delgated this contract to spend coin for levelup
        require(
            coin.allowance(msg.sender, address(this)) >= necessaryExp,
            "not enough Coin allowance"
        );
        // whether user have ehough coin to increment level
        require(
            coin.balanceOf(msg.sender) >= necessaryExp,
            "not enough coin to update level"
        );

        try coin.transferFrom(msg.sender, polylemmer, necessaryExp) {
            _updateLevel(tokenId);
        } catch Error(string memory reason) {
            revert ErrorWithLog(reason);
        }
    }

    function _updateLevel(uint256 tokenId) internal {
        uint32 checkNum = numCheckpoints[tokenId];
        CharacterInfo memory charInfoOld = checkpoints[tokenId][checkNum - 1]
            .charInfo;
        CharacterInfo memory charInfoNew = CharacterInfo(
            charInfoOld.name,
            charInfoOld.characterType,
            charInfoOld.fromBlock,
            charInfoOld.level + 1,
            charInfoOld.rarity,
            charInfoOld.abilityIds
        );

        _writeCheckpoint(tokenId, checkNum, charInfoOld, charInfoNew);
    }

    function getNecessaryExp(uint256 tokenId) public view returns (uint256) {
        CharacterInfo memory charInfo = getCurrentCharacterInfo(tokenId);
        return _calcNecessaryExp(charInfo);
    }

    function setDealer(address newDealer) external onlyPolylemmer {
        dealer = newDealer;
    }

    function getDealer() public view returns (address) {
        return dealer;
    }

    /**
     * @notice Gets the current charInfo for `tokenId`
     * @param tokenId The id of token to get charInfo
     * @return CharacterInfo for `tokenId`
     */
    function getCurrentCharacterInfo(uint256 tokenId)
        public
        view
        returns (CharacterInfo memory)
    {
        CharacterInfo memory dummyInfo = CharacterInfo("", "", 0, 0, 0, [0]);
        uint32 nCheckpoints = numCheckpoints[tokenId];
        return
            nCheckpoints > 0
                ? checkpoints[tokenId][nCheckpoints - 1].charInfo
                : dummyInfo;
    }

    /**
     * @notice Determine the prior charInfo for an tokenId as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param tokenId The address of the token to check
     * @param blockNumber The block number to get the charInfo at
     * @return CharacterInfo of the token had as of the given block
     */
    function getPriorCharacterInfo(uint256 tokenId, uint256 blockNumber)
        public
        view
        returns (CharacterInfo memory)
    {
        CharacterInfo memory dummyInfo = CharacterInfo("", "", 0, 0, 0, [0]);
        require(
            blockNumber < block.number,
            "PLMToken::getPriorCharInfo: not yet determined"
        );

        uint32 nCheckpoints = numCheckpoints[tokenId];
        if (nCheckpoints == 0) {
            return dummyInfo;
        }

        // First check most recent balance
        if (checkpoints[tokenId][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[tokenId][nCheckpoints - 1].charInfo;
        }

        // Nest check implicit zero balance
        if (checkpoints[tokenId][0].fromBlock > blockNumber) {
            return dummyInfo;
        }

        /// @notice calc the array index where the blockNumber that you want to search is placed by binary search
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[tokenId][center];
            if (cp.fromBlock == blockNumber) {
                return cp.charInfo;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[tokenId][lower].charInfo;
    }

    /// descript how is the token minted
    /// generate token attributes pattern randomly with seeder, if you want to mint defined patterns in defined numbers of pieces,
    ///      you have to edit this function.
    function _mintTo(
        address to,
        uint256 tokenId,
        bytes32 name
    ) internal returns (uint256) {
        PLMSeeder.Seed memory seed = PLMSeeder.generateSeed(
            tokenId,
            IPLMData(address(this))
        );
        string[] memory characterTypes = getCharacterTypes();
        // TODO: write checkpoint
        CharacterInfo memory mintedCharInfo = CharacterInfo(
            name,
            characterTypes[seed.characterType],
            block.number,
            1,
            _calcRarity(seed.characterType, [seed.ability]),
            [seed.ability]
        );

        // write checkpoint
        uint32 checkNum = numCheckpoints[tokenId];
        CharacterInfo memory dummyInfo = CharacterInfo("", "", 0, 0, 0, [0]);
        _writeCheckpoint(tokenId, checkNum, dummyInfo, mintedCharInfo);

        // mint abiding by ERC721
        _mint(to, tokenId);
        return tokenId;
    }

    /// @notice reset bondLevel when the token is transfered
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        uint256 tokenId = firstTokenId;
        uint32 checkNum = numCheckpoints[tokenId];
        CharacterInfo memory charInfoOld = checkpoints[tokenId][checkNum - 1]
            .charInfo;
        CharacterInfo memory charInfoNew = CharacterInfo(
            charInfoOld.name,
            charInfoOld.characterType,
            block.number,
            charInfoOld.level,
            charInfoOld.rarity,
            charInfoOld.abilityIds
        );

        _writeCheckpoint(tokenId, checkNum, charInfoOld, charInfoNew);
    }

    function _writeCheckpoint(
        uint256 tokenId,
        uint32 nCheckpoints,
        CharacterInfo memory oldCharacterInfo,
        CharacterInfo memory newCharacterInfo
    ) internal {
        uint32 blockNumber = safe32(
            block.number,
            "PLMToken::_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            checkpoints[tokenId][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[tokenId][nCheckpoints - 1].charInfo = newCharacterInfo;
        } else {
            checkpoints[tokenId][nCheckpoints] = Checkpoint(
                blockNumber,
                newCharacterInfo
            );
            numCheckpoints[tokenId] = nCheckpoints + 1;
        }

        emit CharacterInfoChanged(tokenId, oldCharacterInfo, newCharacterInfo);
    }

    function safe32(uint256 n, string memory errorMessage)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
}
