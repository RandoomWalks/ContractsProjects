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
    uint public totalMembers; // Track total members for quorum calculation
    Proposal[] public proposals;

    uint public constant yesVoteThreshold = 50; // 50%
    uint public constant quorum = 25; // 25%
    uint public constant MAX_DESCRIPTION_LENGTH = 200; // Maximum length for proposal descriptions

    event ProposalCreated(uint indexed proposalId, string description);
    event Voted(uint indexed proposalId, address voter, bool vote);
    event ProposalExecuted(uint indexed proposalId, bool success);

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Initially, only the contract owner is a member
        addMember(owner); // Use addMember to ensure totalMembers is updated
    }

    /**
     * @dev Allows the contract owner to add a new member.
     * @param _member The address of the new member.
     */
    function addMember(address _member) public {
        require(msg.sender == owner, "Only the owner can add members");
        if (!members[_member]) { // Check to prevent double counting
            members[_member] = true;
            totalMembers++;
        }
    }
    
    /**
     * @dev Allows the contract owner to remove a member.
     * @param _member The address of the new member.
     */
    function removeMember(address _member) public {
        require(msg.sender == owner, "Only the owner can remove members");
        if (members[_member]) { // Ensure the address is currently a member
            members[_member] = false;
            totalMembers--;
        }
    }
    
    /**
     * @dev Allows a member to create a new proposal.
     * @param _description The description of the proposal.
     */
    function createProposal(string memory _description) external onlyMember {
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        Proposal storage newProposal = proposals.push();
        newProposal.description = _description;
        emit ProposalCreated(proposals.length - 1, _description);
    }
    
    /**
     * @dev Allows a member to vote on a proposal.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _vote The vote (true for yes, false for no).
     */
    function vote(uint _proposalId, bool _vote) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.voted[msg.sender], "Already voted");
        proposal.voted[msg.sender] = true;

        if (_vote) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }

        emit Voted(_proposalId, msg.sender, _vote);
    }

    /**
     * @dev Executes a proposal if it has more yes votes than no votes.
     * @param _proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint _proposalId) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        uint participatingMembers = proposal.yesVotes + proposal.noVotes;
        require(participatingMembers * 100 / totalMembers >= quorum, "Quorum not reached");

        bool success = proposal.yesVotes * 100 / participatingMembers >= yesVoteThreshold;
        if (success) {
            proposal.executed = true;
            // Placeholder for executing proposal actions
        }
        emit ProposalExecuted(_proposalId, success);
    }

    function getProposalCount() external view returns (uint) {
        return proposals.length;
    }
}

