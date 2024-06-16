// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAO
 * @dev A more extensive version of a DAO that allows members to create proposals, vote on them, and execute proposals with various functionalities.
 */
contract SimpleDAO {
    struct Proposal {
        string description;
        bool executed;
        uint yesVotes;
        uint noVotes;
        mapping(address => bool) voted;
        uint creationTime;
        uint expiryTime;
        address target;
        bytes callData;
    }

    address public owner;
    mapping(address => bool) public members;
    mapping(address => uint) public votingPower;
    uint public totalMembers; // Track total members for quorum calculation
    Proposal[] public proposals;

    uint public yesVoteThreshold = 50; // 50% approval required for a proposal to pass
    uint public quorum = 25; // 25% of members must vote for a proposal to be valid
    uint public constant MAX_DESCRIPTION_LENGTH = 200; // Maximum length for proposal descriptions

    event ProposalCreated(uint indexed proposalId, string description, uint expiryTime, address target, bytes callData);
    event Voted(uint indexed proposalId, address voter, bool vote);
    event ProposalExecuted(uint indexed proposalId, bool success);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Not a member");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Initially, only the contract owner is a member
        _addMember(owner); // Use internal function to ensure totalMembers is updated
    }

    /**
     * @dev Allows the contract owner to transfer ownership.
     * @param _newOwner The address of the new owner.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    /**
     * @dev Allows the contract owner to add a new member.
     * @param _member The address of the new member.
     * @param _votingPower The voting power of the new member.
     */
    function addMember(address _member, uint _votingPower) external onlyOwner {
        require(_votingPower > 0, "Voting power must be greater than zero");
        _addMember(_member);
        votingPower[_member] = _votingPower;
    }

    /**
     * @dev Internal function to add a new member.
     * @param _member The address of the new member.
     */
    function _addMember(address _member) internal {
        if (!members[_member]) { // Check to prevent double counting
            members[_member] = true;
            totalMembers++;
        }
    }

    /**
     * @dev Allows the contract owner to remove a member.
     * @param _member The address of the member to remove.
     */
    function removeMember(address _member) external onlyOwner {
        if (members[_member]) { // Ensure the address is currently a member
            members[_member] = false;
            totalMembers--;
            delete votingPower[_member];
        }
    }

    /**
     * @dev Allows the contract owner to update the quorum.
     * @param _quorum The new quorum percentage.
     */
    function updateQuorum(uint _quorum) external onlyOwner {
        require(_quorum > 0 && _quorum <= 100, "Quorum must be between 1 and 100");
        quorum = _quorum;
    }

    /**
     * @dev Allows the contract owner to update the yes vote threshold.
     * @param _yesVoteThreshold The new yes vote threshold percentage.
     */
    function updateYesVoteThreshold(uint _yesVoteThreshold) external onlyOwner {
        require(_yesVoteThreshold > 0 && _yesVoteThreshold <= 100, "Yes vote threshold must be between 1 and 100");
        yesVoteThreshold = _yesVoteThreshold;
    }

    /**
     * @dev Allows a member to create a new proposal.
     * @param _description The description of the proposal.
     * @param _expiryTime The expiry time of the proposal.
     * @param _target The target address for the proposal execution.
     * @param _callData The call data for the proposal execution.
     */
    function createProposal(string memory _description, uint _expiryTime, address _target, bytes memory _callData) external onlyMember {
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(_expiryTime > block.timestamp, "Expiry time must be in the future");

        Proposal storage newProposal = proposals.push();
        newProposal.description = _description;
        newProposal.creationTime = block.timestamp;
        newProposal.expiryTime = _expiryTime;
        newProposal.target = _target;
        newProposal.callData = _callData;

        emit ProposalCreated(proposals.length - 1, _description, _expiryTime, _target, _callData);
    }

    /**
     * @dev Allows a member to vote on a proposal.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _vote The vote (true for yes, false for no).
     */
    function vote(uint _proposalId, bool _vote) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.expiryTime, "Proposal has expired");
        require(!proposal.voted[msg.sender], "Already voted");

        proposal.voted[msg.sender] = true;

        if (_vote) {
            proposal.yesVotes += votingPower[msg.sender];
        } else {
            proposal.noVotes += votingPower[msg.sender];
        }

        emit Voted(_proposalId, msg.sender, _vote);
    }

    /**
     * @dev Executes a proposal if it meets the quorum and voting threshold.
     * @param _proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint _proposalId) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp <= proposal.expiryTime, "Proposal has expired");

        uint participatingMembers = proposal.yesVotes + proposal.noVotes;
        require(participatingMembers * 100 / totalMembers >= quorum, "Quorum not reached");

        bool success = proposal.yesVotes * 100 / participatingMembers >= yesVoteThreshold;
        if (success) {
            proposal.executed = true;
            (bool execSuccess,) = proposal.target.call(proposal.callData);
            require(execSuccess, "Proposal execution failed");
        }

        emit ProposalExecuted(_proposalId, success);
    }

    /**
     * @dev Returns the total number of proposals.
     * @return The number of proposals.
     */
    function getProposalCount() external view returns (uint) {
        return proposals.length;
    }
}
