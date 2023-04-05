// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {Base64} from "openzeppelin-contracts/utils/Base64.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {PLMSeeder} from "./lib/PLMSeeder.sol";
import {Utils} from "./lib/Utils.sol";

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMCoin} from "./interfaces/IPLMCoin.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";

contract PLMToken is ERC721Enumerable, IPLMToken, ReentrancyGuard {
    using Strings for uint8;
    using Strings for uint256;

    /// @notice interface to the coin of polylemma.
    IPLMCoin coin;

    /// @notice interface to the database of polylemma.
    IPLMData data;

    /// @notice admin's address
    address polylemmers;

    /// @notice contract address of the dealer of polylemma.
    address dealer;

    uint256 maxSupply;

    uint256 private currentTokenId = 0;

    /// @notice number of PLMToken images
    uint256 numImg = 38;

    string baseImgURI =
        "https://raw.githubusercontent.com/team-tissis/polylemma-img/main/images/";

    /// @notice The number of totalSupply checkpoints.
    uint32 numTotalSupplyCheckpoints;

    /// @notice A record of totalSupply.
    mapping(uint32 => TotalSupplyCheckpoint) totalSupplyCheckpoints;

    /// @notice The number of characterInfo checkpoints for each token
    mapping(uint256 => uint32) numCharInfoCheckpoints;

    /// @notice A record of charInfo checkpoints for each account, by index.
    /// @dev The key of this map is tokenId.
    mapping(uint256 => mapping(uint32 => CharInfoCheckpoint)) charInfoCheckpoints;

    constructor(
        IPLMCoin _coin,
        IPLMData _data,
        uint256 _maxSupply
    ) ERC721("Polylemma", "PLM") {
        coin = _coin;
        data = _data;
        maxSupply = _maxSupply;
        polylemmers = msg.sender;
    }

    modifier onlyPolylemmers() {
        require(msg.sender == polylemmers, "Sender != polylemmers");
        _;
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "Sender != dealer");
        _;
    }

    /// @notice core logic of levelup.
    /// @dev Because character info has changed by levelup, the new character info
    ///      is written into checkpoints in this function.
    function _updateLevel(uint256 tokenId, uint8 num) internal {
        uint32 checkNum = numCharInfoCheckpoints[tokenId];

        CharacterInfo memory charInfoOld = charInfoCheckpoints[tokenId][
            checkNum - 1
        ].charInfo;
        CharacterInfo memory charInfoNew = CharacterInfo(
            charInfoOld.level + num,
            charInfoOld.rarity,
            charInfoOld.characterTypeId,
            charInfoOld.imgId,
            charInfoOld.fromBlock,
            charInfoOld.attributeIds,
            charInfoOld.name
        );

        emit LevelUped(tokenId, charInfoNew.level);

        _writeCharInfoCheckpoint(tokenId, checkNum, charInfoOld, charInfoNew);
    }

    /// @notice get checkpointFromBloc
    /// @param index  index of checkpoints mapping
    /// @param tokenId it is used when searching CharInfoCheckpoints. In other cases, any value can be taken.
    function _charInfoCheckpointFromBlock(
        uint256 tokenId,
        uint32 index
    ) public view returns (uint256) {
        return charInfoCheckpoints[tokenId][index].fromBlock;
    }

    function _totalSupplyCheckpointFromBlock(
        uint32 index
    ) public view returns (uint256) {
        return totalSupplyCheckpoints[index].fromBlock;
    }

    /// @notice get nCheckpoints
    /// @dev this function can be used for any checkpoints types.
    /// @param tokenId it is used when searching CharInfoCheckpoints. In other cases, any value can be taken.
    function _numCharInfoCheckpoints(
        uint256 tokenId
    ) public view returns (uint32) {
        return numCharInfoCheckpoints[tokenId];
    }

    function _numTotalSupplyCheckpoints() public view returns (uint32) {
        return numTotalSupplyCheckpoints;
    }

    /// @notice Function to mint new PLMToken to the account (to).
    /// @dev 1. generate seed to assign attirbutes to the minted token using Seeder.
    ///      2. write checkpoint of total supply.
    function _mintTo(
        address to,
        uint256 tokenId,
        bytes32 name
    ) internal returns (uint256) {
        PLMSeeder.Seed memory seed = PLMSeeder.generateTokenSeed(
            tokenId,
            IPLMToken(address(this))
        );
        string[] memory characterTypes = data.getCharacterTypes();
        CharacterInfo memory mintedCharInfo = CharacterInfo(
            1,
            data.getRarity([seed.attribute]),
            seed.characterType,
            seed.imgId,
            block.number,
            [seed.attribute],
            name
        );

        // write character info checkpoint
        uint32 charInfoCheckNum = numCharInfoCheckpoints[tokenId];
        CharacterInfo memory dummyInfo = CharacterInfo(0, 0, 0, 0, 0, [0], "");
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

    /// @notice reset bondLevel when the token is transfered.
    /// @dev Before token transfer, update the start block number to initialize bond point.
    ///      Also, update the write character info checkpoint because character info has been changed.
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
            charInfoOld.level,
            charInfoOld.rarity,
            charInfoOld.characterTypeId,
            charInfoOld.imgId,
            block.number,
            charInfoOld.attributeIds,
            charInfoOld.name
        );

        _writeCharInfoCheckpoint(
            tokenId,
            charInfoCheckNum,
            charInfoOld,
            charInfoNew
        );
    }

    /// @notice Function to write new character info checkpoint.
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

    /// @notice Function to write new total supply checkpoint.
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

    function _baseImgURI() internal view returns (string memory) {
        return baseImgURI;
    }

    /// @notice get URL of storage where image png file specifid with imgId is stored
    function _imgURI(uint256 imgId) internal view returns (string memory) {
        return
            bytes(_baseImgURI()).length > 0
                ? string(abi.encodePacked(baseImgURI, imgId.toString(), ".png"))
                : "";
    }

    function _necessaryExp(
        uint256 tokenId,
        uint8 num
    ) internal view returns (uint256) {
        IPLMData.CharacterInfoMinimal memory charInfo = _minimalizeCharInfo(
            _currentCharacterInfo(tokenId)
        );
        return data.getNecessaryExp(charInfo, num);
    }

    function _minimalizeCharInfo(
        CharacterInfo memory charInfo
    ) internal pure returns (IPLMData.CharacterInfoMinimal memory) {
        return
            IPLMData.CharacterInfoMinimal(
                charInfo.level,
                charInfo.characterTypeId,
                charInfo.attributeIds,
                charInfo.fromBlock
            );
    }

    /**
     * @notice Gets the current charInfo for `tokenId`
     * @param tokenId The id of token to get charInfo
     * @return CharacterInfo for `tokenId`
     */
    function _currentCharacterInfo(
        uint256 tokenId
    ) internal view returns (CharacterInfo memory) {
        CharacterInfo memory dummyInfo = CharacterInfo(0, 0, 0, 0, 0, [0], "");
        uint32 nCharInfoCheckpoints = numCharInfoCheckpoints[tokenId];
        return
            nCharInfoCheckpoints > 0
                ? charInfoCheckpoints[tokenId][nCharInfoCheckpoints - 1]
                    .charInfo
                : dummyInfo;
    }

    ////////////////////////
    ///  TOKEN FUNCTIONS ///
    ////////////////////////

    /// @dev By setting gacha contract's address to dealer, only gacha contract can mint
    ///      PLM token.
    function mint(bytes32 name) external onlyDealer returns (uint256) {
        currentTokenId++;
        return _mintTo(dealer, currentTokenId, name);
    }

    /// // FIXME: Burn function should be modified later.
    /// //        (e.g.) get PLM coin instead. but, the refunding amout should be lower than
    /// //               gacha fee.
    /// function burn(uint256 tokenId) external onlyDealer {
    ///     _burn(tokenId);
    /// }

    /// @notice update level by num while consuming his coin
    function updateLevel(uint256 tokenId, uint8 num) external nonReentrant {
        require(msg.sender == ownerOf(tokenId), "sender != owner");
        require(
            _currentCharacterInfo(tokenId).level + num <= 255 && num >= 0,
            "levelup by num is infeasible."
        );

        uint256 necessaryExp = _necessaryExp(tokenId, num);
        try coin.transferFrom(msg.sender, polylemmers, necessaryExp) {
            _updateLevel(tokenId, num);
        } catch Error(string memory reason) {
            revert ErrorWithLog(reason);
        }
    }

    /// @notice Function to return tokenURI.
    /// @dev The output of this function will be used by OpenSea.
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, IPLMToken) returns (string memory) {
        require(_exists(tokenId), "tokenId doesn't exist");

        CharacterInfo memory charInfo = _currentCharacterInfo(tokenId);

        // (e.g.) PLM #5 monster
        string memory name_ = string(
            abi.encodePacked(
                "PLM #",
                tokenId.toString(),
                " ",
                bytes32ToString(charInfo.name)
            )
        );
        string memory attributes = "[";
        attributes = string(
            abi.encodePacked(
                attributes,
                '{"trait_type": "Type", "value": "',
                data.getTypeName(charInfo.characterTypeId),
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
                            _imgURI(charInfo.imgId),
                            '"',
                            ', "attributes": ',
                            attributes,
                            "}"
                        )
                    )
                )
            );
    }

    function minimalizeCharInfo(
        CharacterInfo memory charInfo
    ) external view returns (IPLMData.CharacterInfoMinimal memory) {
        return _minimalizeCharInfo(charInfo);
    }

    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    /// @notice Function to return the tokenIds of tokens owned by the account.
    function getAllTokenOwned(
        address account
    ) external view returns (uint256[] memory) {
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

    // TODO: We should optimize this function to reduce gas fee in the future.
    /// @notice Function to get the list of existing all characters' information.
    function getAllCharacterInfo()
        external
        view
        returns (CharacterInfo[] memory)
    {
        CharacterInfo[] memory allCharacterInfos = new CharacterInfo[](
            currentTokenId
        );
        for (uint256 i = 0; i < currentTokenId; i++) {
            // tokenId is from 1. array index is from 0.
            allCharacterInfos[i] = _currentCharacterInfo(i + 1);
        }
        return allCharacterInfos;
    }

    /// @notice Function to get the length of the owned period of the PLM token designated
    ///         by tokenId.
    /// @dev This function is called when calculating bond point in battle field contract.
    function getElapsedFromBlock(
        uint256 tokenId
    ) external view returns (uint256) {
        return block.number - _currentCharacterInfo(tokenId).fromBlock;
    }

    function getNecessaryExp(
        uint256 tokenId,
        uint8 num
    ) external view returns (uint256) {
        return _necessaryExp(tokenId, num);
    }

    function getDealer() external view returns (address) {
        return dealer;
    }

    /**
     * @notice Gets the current charInfo for `tokenId`
     * @param tokenId The id of token to get charInfo
     * @return CharacterInfo for `tokenId`
     */
    function getCurrentCharacterInfo(
        uint256 tokenId
    ) public view returns (CharacterInfo memory) {
        return _currentCharacterInfo(tokenId);
    }

    /**
     * @notice Determine the prior charInfo for an tokenId as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param tokenId The address of the token to check
     * @param blockNumber The block number to get the charInfo at
     * @return CharacterInfo of the token had as of the given block
     */

    function getPriorCharacterInfo(
        uint256 tokenId,
        uint256 blockNumber
    ) external view returns (CharacterInfo memory) {
        CharacterInfo memory dummyInfo = CharacterInfo(0, 0, 0, 0, 0, [0], "");
        require(blockNumber <= block.number, "blockNumber larger than latest");

        uint256[] memory numArgs = new uint256[](1);
        numArgs[0] = tokenId;
        uint256[] memory elementArgs = new uint256[](1);
        elementArgs[0] = tokenId;

        (uint32 index, bool found) = Utils.getPrior(
            blockNumber,
            address(this),
            "_numCharInfoCheckpoints(uint256)",
            "_charInfoCheckpointFromBlock(uint256,uint32)",
            numArgs,
            elementArgs
        );

        if (!found) {
            return dummyInfo;
        } else {
            return charInfoCheckpoints[tokenId][index].charInfo;
        }
    }

    function getImgURI(uint256 imgId) external view returns (string memory) {
        return _imgURI(imgId);
    }

    function getPriorTotalSupply(
        uint256 blockNumber
    ) external view returns (uint256) {
        uint256 dummyTotalSupply = 0;
        require(blockNumber < block.number, "blockNumber lager than latest");

        uint256[] memory numArgs;
        uint256[] memory elementArgs;

        // TODO change
        (uint32 index, bool found) = Utils.getPrior(
            blockNumber,
            address(this),
            "_numTotalSupplyCheckpoints()",
            "_totalSupplyCheckpointFromBlock(uint32)",
            numArgs,
            elementArgs
        );

        if (!found) {
            return dummyTotalSupply;
        } else {
            return totalSupplyCheckpoints[index].totalSupply;
        }
    }

    function getNumImg() external view returns (uint256) {
        return numImg;
    }

    function getDataAddr() external view returns (address) {
        return address(data);
    }

    ////////////////////////
    ///      SETTERS     ///
    ////////////////////////

    function setDealer(address newDealer) external {
        dealer = newDealer;
    }

    function setNumImg(uint256 _numImg) external onlyPolylemmers {
        numImg = _numImg;
    }

    function setBaseImgURI(
        string calldata _newBaseImgURI
    ) external onlyPolylemmers {
        baseImgURI = _newBaseImgURI;
    }

    ////////////////////////
    ///      UTILS       ///
    ////////////////////////

    function bytes32ToString(
        bytes32 _bytes32
    ) public pure returns (string memory) {
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
}
