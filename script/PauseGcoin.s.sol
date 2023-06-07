// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";

contract PauseGcoin is Script {
    function run() external {
        string memory json = vm.readFile("./deploy/test.json");
        address gcoinAddress = vm.parseJsonAddress(json, ".GCoin");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GCoin gcoin = GCoin(gcoinAddress);
        gcoin.pause();

        vm.stopBroadcast();
    }
}
