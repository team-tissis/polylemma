pragma solidity 0.8.17;

import { IPlmSeeder } from './interfaces/IPlmSeeder.sol';
import { IPlmData } from './interfaces/IPlmData.sol';

contract PlmSeeder is IPlmSeeder {
    /// @notice generate trait seed for mint
    /// @dev generate trait seed for mint according to odds ratio array defined in plmData contract
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    function generateSeed(uint tokenId, IPlmdata data) external view override returns(Seed) {
        uint256 pseudorandomness = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), tokenId))
        );

        uint256 numOddsCharacterType = data.numOddsCharacterType();
        uint256 numOddsAbility =data.numOddsAbility();

        return Seed({
            characterType: data.characterTypeOdds[pseudorandomness % numOddsCharacterType],
            ability: data.abilityOdds[pseudorandomness % numOddsAbility]
        });
}
