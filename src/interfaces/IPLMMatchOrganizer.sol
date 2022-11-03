import {IPLMBattleField} from "./IPLMBattleField.sol";

interface IPLMMatchOrganizer is IPLMBattleField {
    struct BattleProposal {
        address proposer;
        uint16 upperBound;
        uint16 lowerBound;
        uint16 totalLevel;
        uint256 startBlockNum;
        uint256[4] fixedSlots;
    }

    enum MatchState {
        NonProposal,
        Proposal,
        InBattle
    }

    event ProposalCreated(address indexed proposer, BattleProposal createdProp);

    event ProposalDeleted(address indexed proposer, BattleProposal deletedProp);

    error ProposerIsNotOwner(string reason);
}
