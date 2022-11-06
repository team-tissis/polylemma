// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Base64} from "openzeppelin-contracts/utils/Base64.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {PLMSeeder} from "./lib/PLMSeeder.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {PLMData} from "./subcontracts/PLMData.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";

contract PLMToken is ERC721Enumerable, PLMData, IPLMToken, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint8;
    using Strings for uint256;

    address polylemmer;
    address dealer;
    address enhancer;
    bool DealerIsSet = false;
    uint256 maxSupply;
    IPLMCoin coin;
    string baseImgURI =
        "https://raw.githubusercontent.com/team-tissis/polylemma-img/main/images/";

    uint256 private currentTokenId = 0;

    /// @notice A record of charInfo checkpoints for each account, by index.
    /// @dev The key of this map is tokenId.
    mapping(uint256 => mapping(uint32 => CharInfoCheckpoint)) charInfoCheckpoints;

    /// @notice The number of characterInfo checkpoints for each token
    mapping(uint256 => uint32) public numCharInfoCheckpoints;

    /// @notice A record of totalSupply.
    mapping(uint32 => TotalSupplyCheckpoint) totalSupplyCheckpoints;

    /// @notice The number of totalSupply checkpoints.
    uint32 numTotalSupplyCheckpoints;

    modifier onlyPolylemmer() {
        require(
            msg.sender == polylemmer,
            "Permission denied. Sender is not polylemmer."
        );
        _;
    }

    modifier onlyDealer() {
        require(DealerIsSet, "dealer has not been set.");
        require(
            msg.sender == dealer,
            "Permission denied. Sender is not dealer."
        );
        _;
    }

    constructor(IPLMCoin _coin, uint256 _maxSupply) ERC721("Polylemma", "PLM") {
        polylemmer = msg.sender;
        coin = _coin;
        maxSupply = _maxSupply;
    }

    // dealerにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint(bytes32 name) public onlyDealer returns (uint256) {
        currentTokenId++;
        return _mintTo(dealer, currentTokenId, name);
    }

    // TODO: Is burn func. required?
    // If some reasons arise to impl it
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
        uint32 checkNum = numCharInfoCheckpoints[tokenId];
        CharacterInfo memory charInfoOld = charInfoCheckpoints[tokenId][
            checkNum - 1
        ].charInfo;
        CharacterInfo memory charInfoNew = CharacterInfo(
            charInfoOld.name,
            charInfoOld.imgId,
            charInfoOld.fromBlock,
            charInfoOld.characterType,
            charInfoOld.level + 1,
            charInfoOld.rarity,
            charInfoOld.attributeIds
        );

        _writeCharInfoCheckpoint(tokenId, checkNum, charInfoOld, charInfoNew);
    }

    function getNecessaryExp(uint256 tokenId) public view returns (uint256) {
        CharacterInfo memory charInfo = getCurrentCharacterInfo(tokenId);
        return _calcNecessaryExp(charInfo);
    }

    function setDealer(address newDealer) external onlyPolylemmer {
        DealerIsSet = true;
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
        CharacterInfo memory dummyInfo = CharacterInfo("", 0, 0, "", 0, 0, [0]);
        uint32 nCharInfoCheckpoints = numCharInfoCheckpoints[tokenId];
        return
            nCharInfoCheckpoints > 0
                ? charInfoCheckpoints[tokenId][nCharInfoCheckpoints - 1]
                    .charInfo
                : dummyInfo;
    }

    /// @notice bond level is a specification that the longer it is in possession, the more it is enhanced.
    /// The character can be enhanced up to the twice as much level as its normal level.
    function _calcBondLevel(
        uint8 level,
        uint256 startBlock,
        uint256 lastBlock
    ) internal pure returns (uint32) {
        uint256 blockPeriod = 50; // TODO: 大きくする
        uint32 ownershipPeriod = uint32((lastBlock - startBlock) / blockPeriod);
        return ownershipPeriod < level * 2 ? ownershipPeriod : level * 2;
    }

    function calcCurrentBondLevel(uint8 level, uint256 startBlock)
        public
        view
        returns (uint32)
    {
        return _calcBondLevel(level, startBlock, block.number);
    }

    function calcPriorBondLevel(
        uint8 level,
        uint256 startBlock,
        uint256 lastBlock
    ) public pure returns (uint32) {
        return _calcBondLevel(level, startBlock, lastBlock);
    }

    function getPriorTotalSupply(uint256 blockNumber)
        public
        view
        returns (uint256)
    {
        uint256 dummyTotalSupply = 0;
        require(
            blockNumber < block.number,
            "PLMToken::getPriorTokenSupply: not yet determined"
        );

        (uint32 index, bool found) = _searchTotalSupplyCheckpointIdx(
            blockNumber
        );

        if (!found) {
            return dummyTotalSupply;
        } else {
            return totalSupplyCheckpoints[index].totalSupply;
        }
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
        CharacterInfo memory dummyInfo = CharacterInfo("", 0, 0, "", 0, 0, [0]);
        require(
            blockNumber < block.number,
            "PLMToken::getPriorCharInfo: not yet determined"
        );

        (uint32 index, bool found) = _searchCharInfoCheckpointIdx(
            tokenId,
            blockNumber
        );

        if (!found) {
            return dummyInfo;
        } else {
            return charInfoCheckpoints[tokenId][index].charInfo;
        }
    }

    function _searchTotalSupplyCheckpointIdx(uint256 blockNumber)
        internal
        view
        returns (uint32, bool)
    {
        if (numTotalSupplyCheckpoints == 0) {
            return (0, false);
        }

        // First check most recent balance
        if (
            totalSupplyCheckpoints[numTotalSupplyCheckpoints - 1].fromBlock <=
            blockNumber
        ) {
            return (numTotalSupplyCheckpoints - 1, true);
        }

        // Next check implicit zero balance
        if (totalSupplyCheckpoints[0].fromBlock > blockNumber) {
            return (0, false);
        }

        /// @notice calc the array index where the blockNumber that you want to search is placed by binary search
        uint32 lower = 0;
        uint32 upper = numTotalSupplyCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            TotalSupplyCheckpoint memory cp = totalSupplyCheckpoints[center];
            if (cp.fromBlock == blockNumber) {
                return (center, true);
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return (lower, true);
    }

    function _searchCharInfoCheckpointIdx(uint256 tokenId, uint256 blockNumber)
        internal
        view
        returns (uint32, bool)
    {
        uint32 nCharInfoCheckpoints = numCharInfoCheckpoints[tokenId];
        if (nCharInfoCheckpoints == 0) {
            return (0, false);
        }

        // First check most recent balance
        if (
            charInfoCheckpoints[tokenId][nCharInfoCheckpoints - 1].fromBlock <=
            blockNumber
        ) {
            return (nCharInfoCheckpoints - 1, true);
        }

        // Nest check implicit zero balance
        if (charInfoCheckpoints[tokenId][0].fromBlock > blockNumber) {
            return (0, false);
        }

        /// @notice calc the array index where the blockNumber that you want to search is placed by binary search
        uint32 lower = 0;
        uint32 upper = nCharInfoCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            CharInfoCheckpoint memory cp = charInfoCheckpoints[tokenId][center];
            if (cp.fromBlock == blockNumber) {
                return (center, true);
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return (lower, true);
    }

    function setNumImg(uint256 _numImg) external onlyPolylemmer {
        numImg = _numImg;
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
        CharacterInfo memory mintedCharInfo = CharacterInfo(
            name,
            seed.imgId,
            block.number,
            characterTypes[seed.characterType],
            1,
            _calcRarity(seed.characterType, [seed.attribute]),
            [seed.attribute]
        );

        // write character info checkpoint
        uint32 charInfoCheckNum = numCharInfoCheckpoints[tokenId];
        CharacterInfo memory dummyInfo = CharacterInfo("", 0, 0, "", 0, 0, [0]);
        _writeCharInfoCheckpoint(
            tokenId,
            charInfoCheckNum,
            dummyInfo,
            mintedCharInfo
        );

        // write total supply checkpoint
        _writeTotalSupplyCheckpoint();

        // mint abiding by ERC721
        _mint(to, tokenId);
        return tokenId;
    }

    /// @notice get URL of storage where image png file specifid with imgId is stored
    function getImgURI(uint256 imgId) public view returns (string memory) {
        return
            bytes(_baseImgURI()).length > 0
                ? string(abi.encodePacked(baseImgURI, imgId.toString(), ".png"))
                : "";
    }

    function _baseImgURI() internal view returns (string memory) {
        return baseImgURI;
    }

    function setBaseImgURI(string calldata _newBaseImgURI)
        external
        onlyPolylemmer
    {
        baseImgURI = _newBaseImgURI;
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
        uint32 charInfoCheckNum = numCharInfoCheckpoints[tokenId];
        CharacterInfo memory charInfoOld = charInfoCheckpoints[tokenId][
            charInfoCheckNum - 1
        ].charInfo;
        CharacterInfo memory charInfoNew = CharacterInfo(
            charInfoOld.name,
            charInfoOld.imgId,
            block.number,
            charInfoOld.characterType,
            charInfoOld.level,
            charInfoOld.rarity,
            charInfoOld.attributeIds
        );

        _writeCharInfoCheckpoint(
            tokenId,
            charInfoCheckNum,
            charInfoOld,
            charInfoNew
        );
    }

    function _writeCharInfoCheckpoint(
        uint256 tokenId,
        uint32 nCharInfoCheckpoints,
        CharacterInfo memory oldCharacterInfo,
        CharacterInfo memory newCharacterInfo
    ) internal {
        if (
            nCharInfoCheckpoints > 0 &&
            charInfoCheckpoints[tokenId][nCharInfoCheckpoints - 1].fromBlock ==
            block.number
        ) {
            charInfoCheckpoints[tokenId][nCharInfoCheckpoints - 1]
                .charInfo = newCharacterInfo;
        } else {
            charInfoCheckpoints[tokenId][
                nCharInfoCheckpoints
            ] = CharInfoCheckpoint(block.number, newCharacterInfo);
            numCharInfoCheckpoints[tokenId] = nCharInfoCheckpoints + 1;
        }

        emit CharacterInfoChanged(tokenId, oldCharacterInfo, newCharacterInfo);
    }

    function _writeTotalSupplyCheckpoint() internal {
        if (
            numTotalSupplyCheckpoints > 0 &&
            totalSupplyCheckpoints[numTotalSupplyCheckpoints - 1].fromBlock ==
            block.number
        ) {
            totalSupplyCheckpoints[numTotalSupplyCheckpoints - 1]
                .totalSupply = totalSupply();
        } else {
            totalSupplyCheckpoints[
                numTotalSupplyCheckpoints
            ] = TotalSupplyCheckpoint(block.number, totalSupply());
            numTotalSupplyCheckpoints++;
        }
    }

    function bytes32ToString(bytes32 _bytes32)
        public
        pure
        returns (string memory)
    {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, IPLMToken)
        returns (string memory)
    {
        require(_exists(tokenId), "tokenId doesn't exist");

        CharacterInfo memory charInfo = getCurrentCharacterInfo(tokenId);

        // (e.g.) PLM #5 monster
        string memory name_ = string(
            abi.encodePacked(
                "PLM #",
                tokenId.toString(),
                " ",
                bytes32ToString(charInfo.name)
            )
        );
        // TODO
        string memory attributes = "[";
        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "Type", "value": "',
                charInfo.characterType,
                '"}'
            )
        );
        attributes = string(
            abi.encodePacked(
                attributes,
                ', {"trait_type": "Level", "value": "',
                charInfo.level.toString(),
                '"}'
            )
        );
        attributes = string(
            abi.encodePacked(
                attributes,
                ', {"trait_type": "Rarity", "value": "',
                charInfo.rarity.toString(),
                '"}'
            )
        );
        for (uint8 i = 0; i < charInfo.attributeIds.length; i++) {
            attributes = string(
                abi.encodePacked(
                    attributes,
                    ', {"trait_type": "attribute #',
                    (i + 1).toString(),
                    '", "value": "',
                    charInfo.attributeIds[i].toString(),
                    '"}'
                )
            );
        }
        attributes = string(abi.encodePacked(attributes, "]"));

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            "{",
                            '"name": "',
                            name_,
                            '"',
                            ', "image": "',
                            getImgURI(charInfo.imgId),
                            '"',
                            ', "attributes": ',
                            attributes,
                            "}"
                        )
                    )
                )
            );
    }
}
