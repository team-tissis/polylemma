pragma solidity ^0.8.17;

import {IPlmSeeder} from "./interfaces/IPlmSeeder.sol";
import {IPlmData} from "./interfaces/IPlmData.sol";

contract PlmSeeder is IPlmSeeder {
    function generateSeed(uint256 tokenId, IPlmData data)
        external
        view
        override
        returns (Seed memory)
    {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), tokenId))
        );

        uint256 numOddsCharacterType = data.numOddsCharacterType();
        uint256 numOddsAbility = data.numOddsAbility();

        return
            Seed({
                characterType: data.characterTypeOdds[
                    pseudorandomness % numOddsCharacterType
                ],
                ability: data.abilityOdds[pseudorandomness % numOddsAbility]
            });
    }
}
