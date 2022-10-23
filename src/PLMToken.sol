// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPLMToken} from "./interfaces/IPLMToken.sol";
import {IPLMSeeder} from "./interfaces/IPLMSeeder.sol";
import {IPLMData} from "./interfaces/IPLMData.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PLMToken is ERC721Enumerable, IPLMToken {
    using Counters for Counters.Counter;

    address minter;
    uint256 maxSupply;
    IPLMSeeder seeder;
    IPLMData data;

    uint256 private currentTokenId = 0;

    // TODO: ガス代が小さくなるようにtypeを決めるべき
    // interfaceに宣言するべき？

    // tokenId => characterInfo
    mapping(uint256 => CharacterInfo) characterInfos;
    // address => public key
    mapping(address => bytes32) publicKeys;

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
        uint256 _maxSupply
    ) ERC721("Polylemma", "PLM") {
        minter = _minter;
        seeder = _seeder;
        data = _data;
        maxSupply = _maxSupply;
    }

    // TODO: minterにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint() public onlyMinter returns (uint256) {
        return _mintTo(minter, currentTokenId++);
    }

    function getCharacterInfo(uint256 tokenId)
        public
        view
        returns (CharacterInfo memory)
    {
        return characterInfos[tokenId];
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
            allCharacterInfos[i] = characterInfos[i];
        }
        return allCharacterInfos;
    }

    /// descript how is the token minted
    /// generate token attributes pattern randomly with seeder, if you want to mint defined patterns in defined numbers of pieces,
    ///      you have to edit this function.
    function _mintTo(address to, uint256 tokenId) internal returns (uint256) {
        IPLMSeeder.Seed memory seed = seeder.generateSeed(tokenId, data);
        string[] memory characterTypes = data.getCharacterTypes();
        characterInfos[tokenId] = CharacterInfo(
            characterTypes[seed.characterType],
            1,
            data.calcRarity(seed.characterType, [seed.ability]),
            [seed.ability]
        );
        // TODO; is it right??
        _mint(to, tokenId);
        // TODO: event
        return tokenId;
    }
}
