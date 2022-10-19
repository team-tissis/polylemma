

pragma solidity 0.8.15;

import { IPolylemmaSeeder } from './interfaces/IPolylemmaSeeder.sol';
import { IPolylemmaData } from './interfaces/IPolylemmaData.sol';

contract PolylemmaSeeder is IPolylemmaSeeder {
    function generateSeed(uint tokenId, IPolylemmadata data) external view override returns(Seed) {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), tokenId))
        );

        uint256 characterCount = data.countCharacters();
        uint256 abilityCount = descriptor.countAbilities();

        return Seed({
            character: uint48(
                uint48(pseudorandomness) % characterCount
            ),
            ability: uint48(
                uint48(pseudorandomness >> 48) % abilityCount
            ),
        });
}
