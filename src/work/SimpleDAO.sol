// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAO
 * @dev A simplified version of a DAO that allows members to create proposals,
 */
contract SimpleDAO {
    struct Proposal {
        string description;
        bool executed;
        uint yesVotes;
        uint noVotes;
        mapping(address => bool) voted;
    }

    address public owner;
    mapping(address => bool) public members;
    Proposal[] public proposals;

    event ProposalCreated(uint proposalId, string description);
    event Voted(uint proposalId, address voter, bool vote);
    event ProposalExecuted(uint proposalId);

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Initially, only the contract owner is a member
        members[owner] = true;
    }

    /**
     * @dev Allows the contract owner to add a new member.
     * @param _member The address of the new member.
     */
    function addMember(address _member) public {
        require(msg.sender == owner, "Only the owner can add members");
        members[_member] = true;
    }

    /**
     * @dev Allows a member to create a new proposal.
     * @param _description The description of the proposal.
     */
    function createProposal(string memory _description) public onlyMember {
        Proposal storage newProposal = proposals.push();
        newProposal.description = _description;

        emit ProposalCreated(proposals.length - 1, _description);
    }

    /**
     * @dev Allows a member to vote on a proposal.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _vote The vote (true for yes, false for no).
     */
    function vote(uint _proposalId, bool _vote) public onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.voted[msg.sender], "Already voted");

        if (_vote) {
            proposal.yesVotes += 1;
        } else {
            proposal.noVotes += 1;
        }
        proposal.voted[msg.sender] = true;

        emit Voted(_proposalId, msg.sender, _vote);
    }

    /**
     * @dev Executes a proposal if it has more yes votes than no votes.
     * @param _proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint _proposalId) public onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.yesVotes > proposal.noVotes, "More no votes than yes votes");

        // Placeholder for proposal action execution

        proposal.executed = true;
        emit ProposalExecuted(_proposalId);
    }
}
