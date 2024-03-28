// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// Since Solidity does not support floating-point numbers, decimals or fractional values are typically handled using fixed-point arithmetic or by scaling integers. A common practice is to represent decimals with integers by defining a base unit and scaling the integer values. For example, cryptocurrencies like Ether are often dealt with in their smallest unit, Wei, where 



contract EtherWeiExample {
    // Function to accept ETH and convert the value to Wei
    function donate() public payable {
        // msg.value is in Wei
        uint256 amountInWei = msg.value;

        // Convert Wei to Ether
        uint256 amountInEther = amountInWei / 1 ether;

        // Log the amount in Wei and Ether
        emit DonationReceived(msg.sender, amountInWei, amountInEther);
    }

    // Event to log the donation details
    event DonationReceived(address donor, uint256 amountInWei, uint256 amountInEther);

    // Function to return the contract balance in Ether
    function getBalanceInEther() public view returns (uint256) {
        return address(this).balance / 1 ether;
    }

    // Function to return the contract balance in Wei
    function getBalanceInWei() public view returns (uint256) {
        return address(this).balance;
    }
}



contract GasExample {
    uint256 public totalGasUsed;

    // Function that performs operations and tracks gas usage
    function performOperations() public {
        uint256 gasAtStart = gasleft();

        // Example operation
        uint256 sum = 0;
        for (uint256 i = 0; i < 100; i++) {
            sum += i;
        }

        uint256 gasUsed = gasAtStart - gasleft();
        totalGasUsed += gasUsed;

        // Log the gas used for this operation
        emit OperationsPerformed(msg.sender, gasUsed, tx.gasprice);
    }

    // Event to log the operation details
    event OperationsPerformed(address executor, uint256 gasUsed, uint256 gasPrice);
}

