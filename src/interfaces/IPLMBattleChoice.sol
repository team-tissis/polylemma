
import {IPLMBattleField} from "../interfaces/IPLMBattleField.sol";
interface IPLMBattleChoice {

    function commitChoice(bytes32 commitString) external;
    function revealChoice(
        uint8 levelPoint,
        IPLMBattleField.Choice choice,
        bytes32 bindingFactor
    ) external;
}
