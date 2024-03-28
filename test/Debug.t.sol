
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "forge-std/console.sol";



contract DebuggableContract {
    event DebugLog(string message, uint value);

    function someFunction(uint _value) public {
        console.log("Enter DebuggableContract.someFunction()");
        // Emit an event for debugging
        emit DebugLog("someFunction was called with _value:", _value);

        // Function logic here
    }
}



contract DebuggableContractTest is Test {
    DebuggableContract debuggableContract;

    function setUp() public {
        debuggableContract = new DebuggableContract();
    }

    function testSomeFunction() public {
        uint testValue = 123;
        debuggableContract.someFunction(testValue);
    }
}
