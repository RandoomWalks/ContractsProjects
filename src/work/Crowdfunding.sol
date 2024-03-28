// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Simple Crowdfunding Platform
 * @dev This contract allows users to create crowdfunding campaigns, contribute to them, and withdraw funds once goals are met.
 */
contract Crowdfunding {
    // Structure defining the state of a crowdfunding campaign
    struct Campaign {
        address payable creator; // Address of the campaign creator
        string title; // Title of the campaign
        uint goal; // Funding goal in wei
        uint fundsRaised; // Total funds raised in wei
        uint deadline; // Timestamp of when the campaign ends
        bool isComplete; // Whether the campaign is completed
    }

    uint public numCampaigns; // Counter for the total number of campaigns
    mapping(uint => Campaign) public campaigns; // Mapping of campaignId to Campaign structure

    // Events
    event CampaignCreated(uint campaignId, string title, uint goal, uint deadline);
    event ContributionMade(uint campaignId, address contributor, uint amount);
    event FundsWithdrawn(uint campaignId, uint amount);

    /**
     * @dev Creates a new crowdfunding campaign.
     * @param _title The title of the campaign.
     * @param _goal The funding goal in wei.
     * @param _duration Duration (in seconds) before the campaign ends.
     */
    function createCampaign(string memory _title, uint _goal, uint _duration) public {
        uint deadline = block.timestamp + _duration; 
        campaigns[numCampaigns++] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            goal: _goal,
            fundsRaised: 0,
            deadline: deadline,
            isComplete: false
        });

        emit CampaignCreated(numCampaigns, _title, _goal, deadline); 
    }

    /**
     * @dev Allows contributors to contribute to a campaign.
     * @param _campaignId The ID of the campaign to contribute to.
     */
    function contribute(uint _campaignId) public payable {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp <= campaign.deadline, "Campaign has ended"); 
        require(!campaign.isComplete, "Campaign is already complete");

        campaign.fundsRaised += msg.value; 
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    /**
     * @dev Allows the campaign creator to withdraw funds if the campaign goal is met and the campaign has ended.
     * @param _campaignId The ID of the campaign to withdraw funds from.
     */
    function withdrawFunds(uint _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only the campaign creator can withdraw");
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(campaign.fundsRaised >= campaign.goal, "Funding goal not met");
        require(!campaign.isComplete, "Funds already withdrawn");

        campaign.isComplete = true; 
        campaign.creator.transfer(campaign.fundsRaised); 

        emit FundsWithdrawn(_campaignId, campaign.fundsRaised);
    }

    /**
     * @dev Retrieves the details of a specific campaign.
     * @param _campaignId The ID of the campaign to retrieve.
     * @return The campaign details.
     */
    function getCampaign(uint _campaignId) public view returns (Campaign memory) {
        return campaigns[_campaignId]; 
    }
}
