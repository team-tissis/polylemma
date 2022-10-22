// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPlmToken} from "./interfaces/IPlmToken.sol";
import {IPlmSeeder} from "./interfaces/IPlmSeeder.sol";
import {IPlmData} from "./interfaces/IPlmData.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PlmToken is IPlmToken, ERC721Enumerable {
    using Counters for Counters.Counter;

    address minter;
    uint256 maxSupply;
    IPlmSeeder seeder;
    IPlmData data;

    uint256 private _tokenIds;

    // TODO: ガス代が小さくなるようにtypeを決めるべき
    // interfaceに宣言するべき？
    struct CharacterInfo {
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[1] abilityIds;
    }

    // tokenId => characterInfo
    mapping(uint256 => CharacterInfo) character_infos;

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
        IPlmSeeder _seeder,
        IPlmData _data,
        uint256 _maxSupply
    ) ERC721("Polyles", "POL") {
        minter = _minter;
        seeder = _seeder;
        data = _data;
        maxSupply = _maxSupply;
    }

    // TODO: minterにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint() public override onlyMinter returns (uint256) {
        return _mintTo(minter, _tokenIds++);
    }

    /// descript how is the token minted
    /// generate token attributes pattern randomly with seeder, if you want to mint defined patterns in defined numbers of pieces,
    ///      you have to edit this function.
    function _mintTo(address to, uint256 tokenId) internal returns (uint256) {
        IPlmSeeder.Seed memory seed = seeder.generateSeed(tokenId, data);
        string[] memory characterTypes = data.getCharacterTypes();
        character_infos[tokenId] = CharacterInfo(
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
