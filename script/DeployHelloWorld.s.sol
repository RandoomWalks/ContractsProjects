// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/scratch/HelloWorld.sol";

contract DeployHelloWorld is Script {
    function run() external {
        vm.startBroadcast();

        HelloWorld helloWorld = new HelloWorld();

        vm.stopBroadcast();

        console.log("HelloWorld deployed to:", address(helloWorld));
    }
}
