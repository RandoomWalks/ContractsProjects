// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
contract StringPrac {
    uint256 public ID;

    constructor(uint uID) {
        ID = uID;
    }

    // TODO - why convert to bytes first? Are all complex types just bytes typecasted?

    function getSLen(string memory inp) public pure returns (uint) {
        return bytes(inp).length;
    }

    // TODO - what is abi ?
    // Concatenation: You can concatenate two strings using the abi.encodePacked() function.
    function getConcat(
        string memory s1,
        string memory s2
    ) public pure returns (string memory) {
        string memory sRet = string(abi.encodePacked(s1, "_space", s2));
        return sRet;
    }
}

// TODO - must recompile to get new random
contract RandomNumberGenerator {
    function getRandomNumber() public view returns (uint256) {
        uint256 randomNumber = uint256(
            keccak256(abi.encode(blockhash(block.number - 1), block.timestamp))
        );
        return randomNumber;
    }
}

contract Ownable {
    address private owner;

    // Event declaration for ownership transfer
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Modifier to restrict function access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function getOwner() public returns (address) {
        return owner;
    }
    // Constructor sets the original `owner` of the contract to the sender account.
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract OwnableObj is Ownable {
    uint256 public number;

    function setVal(uint256 newVal) public onlyOwner {
        number = newVal;
    }

    function getVal() public onlyOwner returns (uint256) {
        return number;
    }
}

// msg.data (bytes): complete calldata
// msg.gas (uint): remaining gas - deprecated in version 0.4.21 and to be replaced by gasleft()
// msg.sender (address): sender of the message (current call)
// msg.sig (bytes4): first four bytes of the calldata (i.e. function identifier)
// msg.value (uint): number of wei sent with the message

// Exercise 1: Simple Bank Contract
// Create a simple bank contract where users can deposit and withdraw Ether. Use the following requirements:

// Implement a function to deposit Ether into the contract.
// Implement a function to withdraw Ether from the contract to the caller's address.
// Use a state variable to track the balance of each user.
// Ensure that a user cannot withdraw more Ether than they have deposited.

// TODO: COMMENT ON MISTAKES IM DOING
// TODO: COMMENT ON SECURITY OF THIS
// TODO: COMMENT ON GAS USAGE OF THIS

contract SimpleBankContract {
    mapping(address => uint256) public BankBalance; //  Mappings are by default stored in storage.
    address public immutable owner;

    // indexed keyword is used in event declarations to indicate that the corresponding parameters should be indexed in the event logs.
    // indexed parameters enable efficient filtering and searching of events when querying the blockchain.
    event OwnershipTransferred(
        address indexed prevOwner,
        address indexed newOwner
    );
    event TransferEvent(uint256 uVal, string message, address newOwner);
    event WithdrawEvent(uint256 uVal, address Owner);
    event DepositEvent(uint256 uVal, address Owner, string sCxt);

    function depositBalance() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0"); //  //  prevent zero-value transactions which would still cost users gas.


        address userID = msg.sender;
        uint256 depositAmnt = msg.value; // msg.value contains the amount of wei (ether / 1e18) sent in the transaction.

        BankBalance[userID] += depositAmnt;
        emit DepositEvent(depositAmnt, msg.sender,"deposit - depositBalance()");
    }

    // external avoids copy args to memory , passes directly from caller's memory, 
    // external funcs cannot be modified by derived contracts.
    function getUserBalance() external view returns (uint256) {
        // require(BankBalance[msg.sender] != 0, "Invalid balance for user !"); // default is 0

        return BankBalance[msg.sender];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance; // this is a keyword that refers to the current instance of the contract.
    }

    function withdrawlBalance(uint256 withdrawAmnt) public {
        require(
            withdrawAmnt <= BankBalance[msg.sender],
            "Not enough to withdraw !"
        );
        // payable address, which allows you to send ether to them from your contract.
        BankBalance[msg.sender] -= withdrawAmnt;
        payable(msg.sender).transfer(withdrawAmnt); //  sends amount Wei from the contract to the recipient address.
        emit WithdrawEvent(withdrawAmnt, msg.sender);
    }
    
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // TODO: receive() ,fallback() usage?
    //     // Function to receive ether, msg.data must be empty
    //     // Fallback function is called when msg.data is not empty

    // // Function to receive Ether. msg.data must be empty
    receive() external payable {
        emit DepositEvent(msg.value,msg.sender,"deposit - receive() msg.data is empty ");
    }   

// The msg.data contains the function identifier (first 4 bytes of the keccak256 hash of the function signature) followed by the encoded arguments. T
    fallback() external payable {
        emit DepositEvent(msg.value,msg.sender,"deposit - receive() msg.data not empty ");

    }
}

// Exercise 2: Voting Contract
// Develop a contract for a simple voting system. The contract should allow the contract owner to create a new poll with candidates, allow users to vote if they haven't already, and enable checking the current leading candidate.

// Requirements:
// Creating a Poll: Only the contract owner can create a poll with a list of candidates.
// Voting: Users can vote for candidates by name. Ensure that each address can only vote once per poll.
// Check Leading Candidate: Function to return the curvrent leading candidate based on votes.
// Use of Structs and Mappings: Use structs to represent a Poll and mappings to track votes and if a user has voted.


// contract VotingContract {
//     struct Poll {
        
//     mapping[candidates] = currVotes 
//     set<address> alreadyVoted
//     }
    
    
// }