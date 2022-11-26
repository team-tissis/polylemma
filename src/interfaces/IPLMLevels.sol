import {IPLMData} from "./IPLMData.sol";

interface IPLMLevels {
    ////////////////////////
    ///      GETTERS     ///
    ////////////////////////

    function getCurrentBondLevel(uint8 level, uint256 fromBlock)
        external
        view
        returns (uint32);

    function getPriorBondLevel(
        uint8 level,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (uint32);

    function getLevelPoint(IPLMData.CharacterInfoMinimal[4] calldata charInfos)
        external
        pure
        returns (uint8);

    function getRandomSlotLevel(
        IPLMData.CharacterInfoMinimal[4] calldata charInfos
    ) external pure returns (uint8);
}
