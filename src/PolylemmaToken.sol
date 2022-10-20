// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// TODO: thelatest version is 0.8.17.
pragma solidity 0.8.13;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IPolylesSeeder} from "./interfaces/IPolylesSeeder.sol";

import {Counters} from "openzeppelin-contracts/contracts/utils/Counters.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC020/ERC20.sol";

contract polylemmaToken is IPolylemmaToken, ERC721Enumerable {
    using Counters for Counters.Counter;

    address minter;

    Counters.Counter private _tokenIds;

    // TODO: ガス代が小さくなるようにtypeを決めるべき
    struct CharacterInfo {
        string characterType;
        uint8 level;
        uint8 rarity;
        uint8[] abilityIds;
    }

    mapping(uint256 => character_info) character_infos;

    modifier onlyMinter() {
        require(
            msg.sender == minter,
            "Permission denied. Sender is not minter."
        );
        _;
    }

    modifier enoughLeft() {
        require(totalMinted + _quantity < maxSupply + 1, "Not enough left");
    }

    constructor(
        address _minter,
        IPolylesSeeder _seeder,
        IPolylemmaData _data,
        uint256 _maxSupply
    ) ERC721("Polyles", "POL") {
        minter = _minter;
        seeder = _seeder;
        data = _data;
        maxSupply = _maxSupply;
    }

    // TODO: minterにgachaコントラクトアドレスをセットすることで、gachaからしかmintできないようにする。
    function mint() public onlyMinter {
        return _mintTo(minter, _tokenIds.increment());
    }

    // TODO: not defined
    function burn(uint256 tokenId) public override onlyMinter {
        _burn(tokenId);
    }

    /// @notice descript how is the token minted
    /// @dev generate token attributes pattern randomly with seeder, if you want to mint defined patterns in defined numbers of pieces,
    ///      you have to edit this function.
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    function _mintTo(address to, uint256 tokenId) internal returns (uint256) {
        IPolylemmaSeeder.Seed memory seed = seeder.generateSeed(tokenId, data);
        character_infos[tokenId] = CharacterInfo(
            data.characterType[seed.characterType],
            1,
            data.calcRarity(seed.characterType, seed.ability),
            [data.abilities[seed.ability]]
        );
        _mint(owner(), to, tokenId);
        // TODO: event
        return tokenId;
    }
}
