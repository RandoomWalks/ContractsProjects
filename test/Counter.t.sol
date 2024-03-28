// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter, StringPrac, RandomNumberGenerator, Ownable, OwnableObj} from "../src/scratch/Counter.sol";
import "forge-std/console.sol";

contract CounterTest is Test {
    Counter public counter;
    event DebugLogUint(string message, uint value);

    function setUp() public {
        console.log("Enter CounterTest.setUp()");

        counter = new Counter();
        counter.setNumber(0);
    }

    function test_Increment() public {
        console.log("Enter CounterTest.test_Increment()");

        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        console.log("Enter CounterTest.testFuzz_SetNumber(): ", x);

        counter.setNumber(x);
        emit DebugLogUint("testFuzz_SetNumber: New value is:", x);

        assertEq(counter.number(), x);
    }
}

contract StringPracTest is Test {
    StringPrac public sObj = new StringPrac(1);

    function test_len(string memory sInp) public {
        uint uLen = sObj.getSLen((sInp));
        console.log("test_len(): ", uLen);
    }

    function test_concat() public {
        console.log(sObj.getConcat("abc", "def"));
    }
}

contract RandomNumberGeneratorTest is Test {
    RandomNumberGenerator public randObj = new RandomNumberGenerator();

    function test_randGen() public {
        console.log("randObj.getRandomNumber(): ", randObj.getRandomNumber());
    }
}

contract OwnableTest is Test {
    OwnableObj ownObj;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setUp() public {
        ownObj = new OwnableObj();
    }

    function testFunctionality() public {
        ownObj.setVal(123);
    }
    
    function testOwnershipTransferredEvent() public {
        // Expected event emission
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), address(this));

        // Action causing the event to be emitted
        OwnableObj obj = new OwnableObj();
        console.log("OwnableObj:");
    }
}

contract BasicTest is Test {
    address public immutable ownerImm;

    uint256 public constant MAX_USERS = 1000;

    constructor() {
        ownerImm = msg.sender;
    }

    function f1() public {
        address owner = msg.sender;
        bytes32 hash = keccak256(abi.encodePacked("Hello, World!"));
        bool isActive = true;
        uint256 totalParticipants = 100;
        bytes32 uniqueIdentifier = keccak256((abi.encodePacked("Solidity")));

        // uint256 constant HASH = 1;

        // immutable can be set once inside the constructor or at the point of declaration
        // ownerImm = msg.sender;
    }

    function checkNum(uint _num) public pure returns (string memory) {
        if (_num > MAX_USERS) {
            return "checkNum() FAIL";
        } else {
            return "checkNum() OK";
        }
    }
}

contract EtherWeiTest is Test {
    uint256 private balance;
    enum Denom {
        Eth,
        Gwei,
        Wei
    }

    //  enable a function or address to receive ether.
    function increase() public payable {
        balance += msg.value;
    }

    // 1 ether is equivalent to 10^18 wei, and 1 gwei is 10^9 wei

// Ether to Wei
// 1 eth * 10^18 wei 
// Gwei to Wei
// 1 gwei * 10^9 wei 
// Wei to gwei 
// 1 wei / 10^9 gwei
// wei to ether 
// 1 wei / 10^18 ether 
// gwei to ether
// 1 gwei / 10^9 ether 



    function convertToWei(uint256 val, Denom denom) public returns (uint256) {
        // convert from ether

        if (denom == Denom.Eth) {
            uint256 weiVal = val * 1 wei;
            console.log("weiVal: ", weiVal);
            return weiVal;
        } else if (denom == Denom.Gwei) {
            uint256 gweiVal = val * 1 gwei; // less prone to errors from manually typing out the number of zeros.
            console.log("gweiVal: ", gweiVal);
            return gweiVal;
        } else if (denom == Denom.Wei) {
            uint256 ethVal = val * 1 ether; // Redundant since already in Wei
            console.log("ethVal: ", ethVal);
            return ethVal;
        } else {
            // When revert is triggered, any Ether sent with the transaction is returned to the sender, and the transaction is reverted, meaning that any state changes made during the execution of the transaction are undone.
            revert("Illegal Operation");
            
        }
    }
    // all code paths in a non-void function must return a value. 
    function convertToEth(uint256 val, Denom denom) public pure returns (uint256) {
        // get Eth , ret Eth 
        if (denom == Denom.Eth) {
            return val;
        } else if (denom == Denom.Gwei) {
            // gwei -> wei -> eth
            return (val * 1 gwei) / 1 ether;
        } else if (denom == Denom.Wei) {
            // wei -> eth
            return val / 1 ether ; 
        } else {
            revert("Unknown denom");
        }
    }  
    
    function testConv() public {
        uint256 weiFromEth = convertToWei(1, Denom.Eth);
        uint256 weiFromGwei = convertToWei(1, Denom.Gwei);
        uint256 weiFromWei = convertToWei(1, Denom.Wei);

        console.log("1 Eth in Wei: ", weiFromEth);
        console.log("1 Gwei in Wei: ", weiFromGwei);
        console.log("1 Wei: ", weiFromWei);
    }
}


