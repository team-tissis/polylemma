// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// TODO: thelatest version is 0.8.17.
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";

import {IPolylesSeeder} from "./interfaces/IPolylesSeeder.sol";
import {Counters} from "./lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC020/ERC20.sol";

contract polylemmaToken is IPolylemmaToken, ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    enum CharacterType {
        Fire,
        Water,
        Grass
    }

    // TODO: ガス代が小さくなるようにtypeを決めるべき
    struct character_info {
        string name;
        CharacterType characterType;
        uint8 level;
        uint8 rarity;
        uint8[] abilityIDs;
    }

    mapping(uint256 => character_info) character_infos;

    modifier onlyGameMaster() {
        require(msg.sender == gameMaster, "Sender is not the game master");
        _;
    }

    modifier enoughLeft() {
        require(totalMinted + _quantity < maxSupply + 1, "Not enough left");
    }

    constructor(
        address _gameMaster,
        IPolylesSeeder _seeder,
        IPolylemmaData _data,
        uint256 _maxSupply
    ) ERC721("Polyles", "POL") {
        gameMaster = _gameMaster;
        seeder = _seeder;
        data = _data;
        maxSupply = _maxSupply;
    }

    function mint() public onlyGameMaster {
        return _mintTo(minter, _tokenIds.increment());
    }

    function burn(uint256 nounId) public override onlyMinter {
        _burn(nounId);
        emit NounBurned(nounId);
    }

    /// @notice descript how is the token minted
    /// @dev generate token attributes pattern randomly with seeder, if you want to mint defined patterns in defined numbers of pieces,
    ///      you have to edit this function.
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    function _mintTo(address to, uint256 tokenId) internal returns (uint256) {
        IPolylemmaSeeder.Seed memory seed = seeds[tokenId] = seeder
            .generateSeed(tokenId, data);
        _mint(owner(), to, tokenId);
        emit NounCreated(tokenId, seed);

        return tokenId;
    }
}
