// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAO
 * @dev A more extensive version of a DAO that allows members to create proposals, vote on them, and execute proposals with various functionalities.
 */
contract SimpleDAO {
    enum ProposalType { Regular, Membership, Funding }
    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed }

    struct Proposal {
        ProposalType proposalType;
        ProposalState proposalState;
        string description;
        uint yesVotes;
        uint noVotes;
        mapping(address => bool) voted;
        uint creationTime;
        uint expiryTime;
        address target;
        bytes callData;
        uint deposit;
    }

    struct Member {
        bool isMember;
        uint votingPower;
        address delegate;
    }

    address public owner;
    mapping(address => Member) public members;
    uint public totalMembers;
    Proposal[] public proposals;

    uint public yesVoteThreshold = 50;
    uint public quorum = 25;
    uint public proposalDeposit = 1 ether;
    uint public timelockDuration = 24 hours;
    bool public emergencyStop;

    uint public constant MAX_DESCRIPTION_LENGTH = 200;

    event ProposalCreated(uint indexed proposalId, ProposalType proposalType, string description, uint expiryTime, address target, bytes callData);
    event Voted(uint indexed proposalId, address voter, bool vote);
    event ProposalExecuted(uint indexed proposalId, bool success);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event EmergencyStopActivated();
    event EmergencyStopDeactivated();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isMember, "Not a member");
        _;
    }

    modifier notEmergencyStop() {
        require(!emergencyStop, "Emergency stop is activated");
        _;
    }

    constructor() {
        owner = msg.sender;
        _addMember(owner);
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
        members[_member].votingPower = _votingPower;
    }

    /**
     * @dev Internal function to add a new member.
     * @param _member The address of the new member.
     */
    function _addMember(address _member) internal {
        if (!members[_member].isMember) {
            members[_member].isMember = true;
            totalMembers++;
        }
    }

    /**
     * @dev Allows the contract owner to remove a member.
     * @param _member The address of the member to remove.
     */
    function removeMember(address _member) external onlyOwner {
        if (members[_member].isMember) {
            members[_member].isMember = false;
            totalMembers--;
            delete members[_member];
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
     * @dev Allows a member to delegate their voting power to another member.
     * @param _delegate The address of the member to delegate voting power to.
     */
    function delegateVotingPower(address _delegate) external onlyMember {
        require(members[_delegate].isMember, "Delegate must be a member");
        members[msg.sender].delegate = _delegate;
    }

    /**
     * @dev Allows a member to revoke their voting power delegation.
     */
    function revokeDelegation() external onlyMember {
        delete members[msg.sender].delegate;
    }

    /**
     * @dev Allows a member to create a new proposal.
     * @param _proposalType The type of the proposal.
     * @param _description The description of the proposal.
     * @param _expiryTime The expiry time of the proposal.
     * @param _target The target address for the proposal execution.
     * @param _callData The call data for the proposal execution.
     */
    function createProposal(
        ProposalType _proposalType,
        string memory _description,
        uint _expiryTime,
        address _target,
        bytes memory _callData
    ) external payable onlyMember notEmergencyStop {
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(_expiryTime > block.timestamp, "Expiry time must be in the future");
        require(msg.value == proposalDeposit, "Incorrect proposal deposit");

        Proposal storage newProposal = proposals.push();
        newProposal.proposalType = _proposalType;
        newProposal.proposalState = ProposalState.Pending;
        newProposal.description = _description;
        newProposal.creationTime = block.timestamp;
        newProposal.expiryTime = _expiryTime;
        newProposal.target = _target;
        newProposal.callData = _callData;
        newProposal.deposit = msg.value;

        emit ProposalCreated(proposals.length - 1, _proposalType, _description, _expiryTime, _target, _callData);
    }

    /**
     * @dev Allows a member to vote on a proposal.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _vote The vote (true for yes, false for no).
     */
    function vote(uint _proposalId, bool _vote) external onlyMember notEmergencyStop {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.proposalState == ProposalState.Active, "Proposal is not active");
        require(block.timestamp <= proposal.expiryTime, "Proposal has expired");
        require(!proposal.voted[msg.sender], "Already voted");

        proposal.voted[msg.sender] = true;

        uint votingPower = _getVotingPower(msg.sender);
        if (_vote) {
            proposal.yesVotes += votingPower;
        } else {
            proposal.noVotes += votingPower;
        }

        emit Voted(_proposalId, msg.sender, _vote);

        _updateProposalState(_proposalId);
    }

    /**
     * @dev Executes a proposal if it meets the quorum and voting threshold.
     * @param _proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint _proposalId) external onlyMember notEmergencyStop {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.proposalState == ProposalState.Succeeded, "Proposal has not succeeded");
        require(block.timestamp > proposal.expiryTime + timelockDuration, "Timelock duration has not passed");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;
        (bool success,) = proposal.target.call{value: proposal.deposit}(proposal.callData);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(_proposalId, success);
    }

    /**
     * @dev Allows the contract owner to activate the emergency stop.
     */
    function activateEmergencyStop() external onlyOwner {
        emergencyStop = true;
        emit EmergencyStopActivated();
    }

    /**
     * @dev Allows the contract owner to deactivate the emergency stop.
     */
    function deactivateEmergencyStop() external onlyOwner {
        emergencyStop = false;
        emit EmergencyStopDeactivated();
    }

    /**
     * @dev Returns the total number of proposals.
     * @return The number of proposals.
     */
    function getProposalCount() external view returns (uint) {
        return proposals.length;
    }

    /**
     * @dev Internal function to update the state of a proposal.
     * @param _proposalId The ID of the proposal to update.
     */
    function _updateProposalState(uint _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.proposalState == ProposalState.Pending && block.timestamp > proposal.creationTime) {
            proposal.proposalState = ProposalState.Active;
        }

        if (proposal.proposalState == ProposalState.Active && block.timestamp > proposal.expiryTime) {
            uint participatingMembers = proposal.yesVotes + proposal.noVotes;
            if (participatingMembers * 100 / totalMembers >= quorum) {
                if (proposal.yesVotes * 100 / participatingMembers >= yesVoteThreshold) {
                    proposal.proposalState = ProposalState.Succeeded;
                } else {
                    proposal.proposalState = ProposalState.Defeated;
                }
            } else {
                proposal.proposalState = ProposalState.Defeated;
            }
        }
    }

    /**
     * @dev Internal function to get the voting power of a member.
     * @param _member The address of the member.
     * @return The voting power of the member.
     */
    function _getVotingPower(address _member) internal view returns (uint) {
        address delegate = members[_member].delegate;
        if (delegate != address(0)) {
            return members[delegate].votingPower;
        } else {
            return members[_member].votingPower;
        }
    }
}