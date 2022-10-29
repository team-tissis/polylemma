// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMSeeder} from "./interfaces/IPLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMToken is ERC721Enumerable, IPLMToken {
    using Counters for Counters.Counter;

    address dealer;
    address minter;
    address enhancer;
    uint256 maxSupply;
    IPLMSeeder seeder;
    IPLMCoin coin;
    IPLMData data;

    uint256 private currentTokenId = 0;
    /// @notice A checkpoint for marking change of characterInfo from a given block
    struct Checkpoint {
        uint256 fromBlock;
        CharacterInfo charInfo;
    }
    /// @notice tokenId => characterInfo
    mapping(uint256 => CharacterInfo) characterInfos;
    /// @notice A record of charInfo checkpoints for each account, by index
    mapping(uint256 => Checkpoint[]) checkpoints;
    /// @notice The number of checkpoints for each token
    mapping(uint256 => uint32) public numCheckpoints;

    // for debug
    event Log(string);

    modifier onlyDealer() {
        require(
            msg.sender == dealer,
            "Permission denied. Sender is not dealer."
        );
        _;
    }

    modifier onlyMinter() {
        require(
            msg.sender == minter,
            "Permission denied. Sender is not minter."
        );
        _;
    }

    // modifier enoughLeft() {
    //     require(totalMinted + _quantity < maxSupply + 1, "Not enough left");
    // }

    constructor(
        address _minter,
        IPLMSeeder _seeder,
        IPLMData _data,
        IPLMCoin _coin,
        uint256 _maxSupply
    ) ERC721("Polylemma", "PLM") {
        dealer = msg.sender;
        minter = _minter;
        seeder = _seeder;
        data = _data;
        coin = _coin;
        maxSupply = _maxSupply;
    }

    // minterにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint(bytes20 name) public onlyMinter returns (uint256) {
        currentTokenId++;
        return _mintTo(minter, currentTokenId, name);
    }

    function burn(uint256 tokenId) public onlyMinter {
        _burn(tokenId);
        // TODO: event
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

    function getCharacterInfo(uint256 tokenId)
        public
        view
        returns (CharacterInfo memory)
    {
        return characterInfos[tokenId];
    }

    function getElapsedFromBlock(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return block.number - getCharacterInfo(tokenId).fromBlock;
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
            allCharacterInfos[i] = characterInfos[i + 1];
        }
        return allCharacterInfos;
    }

    /// @notice increment level with consuming his coin
    function updateLevel(uint256 tokenId) external returns (uint8) {
        require(
            msg.sender == ownerOf(tokenId),
            "Permission denied. Sender is not owner of this token"
        );

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

        try coin.transferFrom(msg.sender, dealer, necessaryExp) {
            characterInfos[tokenId].level += 1;
            emit levelUped(characterInfos[tokenId]);
            return characterInfos[tokenId].level;
        } catch Error(string memory reason) {
            emit Log(reason);
            return 0;
        }
    }

    function getNecessaryExp(uint256 tokenId) public view returns (uint256) {
        CharacterInfo memory charInfo = characterInfos[tokenId];
        return data.calcNecessaryExp(charInfo);
    }

    function setMinter(address newMinter) external onlyDealer {
        minter = newMinter;
    }

    function getMinter() public view returns (address) {
        return minter;
    }

    /**
     * @notice Gets the current charInfo for `tokenId`
     * @param tokenId The id of token to get charInfo
     * @return CharacterInfo for `tokenId`
     */
    function getCurrentCharInfo(uint256 tokenId)
        external
        view
        returns (CharacterInfo memory)
    {
        CharacterInfo memory dummyInfo = CharacterInfo("", 0, 0, [0]);
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
    function getPriorCharInfo(uint256 tokenId, uint256 blockNumber)
        public
        view
        returns (CharacterInfo memory)
    {
        CharacterInfo memory dummyInfo = CharacterInfo("", 0, 0, [0]);
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
        bytes20 name
    ) internal returns (uint256) {
        IPLMSeeder.Seed memory seed = seeder.generateSeed(tokenId, data);
        string[] memory characterTypes = data.getCharacterTypes();
        characterInfos[tokenId] = CharacterInfo(
            name,
            characterTypes[seed.characterType],
            block.number,
            1,
            data.calcRarity(seed.characterType, [seed.ability]),
            [seed.ability]
        );
        // TODO; is it right??
        _mint(to, tokenId);
        // TODO: event
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
        characterInfos[tokenId].fromBlock = block.number;
    }
}
