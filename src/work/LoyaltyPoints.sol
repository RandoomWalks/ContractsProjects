// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Loyalty Points System
 * @dev A simple contract to demonstrate a loyalty points system where users can earn points
 * and redeem them for ether. This contract includes basic administrative functions
 */
contract LoyaltyPoints {
    address public owner; // Owner of the contract, typically the deployer
    mapping(address => uint) public pointsBalance; // Tracks the points balance of each user
    mapping(address => bool) public admins; // Tracks who are the admins capable of awarding points

    uint public totalPoints; // Total points issued by the system
    uint public redeemRate = 1 ether; // The rate at which points can be redeemed for ether

    // Events for logging activities on the contract
    event PointsEarned(address indexed user, uint points);
    event PointsRedeemed(address indexed user, uint points, uint redeemRate);
    event RedeemRateUpdated(uint newRedeemRate);

    // Modifier to restrict certain actions to the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Modifier to restrict certain actions to the admins of the contract
    modifier onlyAdmin() {
        require(admins[msg.sender], "Only admin can perform this action");
        _;
    }

    // Constructor sets the deployer as the owner and an admin
    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
        redeemRate = _initialRedeemRate; // Set initial redeem rate at contract deployment
    }

    // Allows the owner to add a new admin
    function addAdmin(address _admin) public onlyOwner {
        admins[_admin] = true;
    }

    // Allows the owner to remove an admin
    function removeAdmin(address _admin) public onlyOwner {
        admins[_admin] = false;
    }

    /**
     * @dev Awards points to a user. Only callable by an admin.
     * @param _user The address of the user to award points.
     * @param _points The number of points to award.
     */
    function earnPoints(address _user, uint _points) public onlyAdmin {
        require(_points > 0, "Points must be greater than 0");
        pointsBalance[_user] += _points;
        totalPoints += _points; // Update the total points issued
        emit PointsEarned(_user, _points);
    }

    /**
     * @dev Redeems points for ether. Each point is worth `redeemRate` ether.
     * @param _points The number of points to redeem.
     */
    function redeemPoints(uint _points) public {
        require(pointsBalance[msg.sender] >= _points, "Insufficient points");
        require(_points > 0, "Points to redeem must be greater than 0");

        uint etherToTransfer = _points * redeemRate;
        // Check that the contract has enough Ether to cover the redemption
        require(address(this).balance >= etherToTransfer, "Contract has insufficient balance for this redemption");
            
        pointsBalance[msg.sender] -= _points; // Deduct points from the user's balance
        totalPoints -= _points; // Adjust the total points issued after redemption

        (bool success, ) = payable(msg.sender).transfer(etherToTransfer); // Transfer ether to the user
        require(success, "Ether transfer failed");

        emit PointsRedeemed(msg.sender, _points, redeemRate);
    }

    /**
     * @dev Allows the owner to update the redeem rate.
     * @param _newRedeemRate The new rate at which points will be redeemed for ether.
     */
    function updateRedeemRate(uint _newRedeemRate) public onlyOwner {
        require(_newRedeemRate > 0, "Redeem rate must be greater than 0");
        redeemRate = _newRedeemRate;
        emit RedeemRateUpdated(_newRedeemRate);
    }
    
    // Allows the owner to deposit ether into the contract. This ether is used for point redemption.
    function depositEther() public payable onlyOwner {}

    // Returns the contract's ether balance. Useful for checking if the contract has enough ether for redemption.
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }
}
