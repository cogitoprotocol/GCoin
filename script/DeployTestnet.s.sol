// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";
import "../src/GCoinStaking.sol";
import "../src/USDTest.sol";
import "../src/CGV.sol";

/**
 * Deploys all contracts including CGV and USDTest, intended for local and testnet
 * Mints 1B CGV to TEST_WALLET
 * Mints 1M USDTest to TEST_WALLET
 */
contract DeployTestnetScript is Script {
    function run() external {
        string memory network = vm.envOr("NETWORK", string("localhost"));

        // TODO: Handle private keys better
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address testWallet = vm.envAddress("TEST_WALLET");

        USDTest usdTest = new USDTest();
        usdTest.mint(testWallet, 1_000_000e6);

        CGV cgv = new CGV();
        cgv.mint(testWallet, 1_000_000_000e6);

        GCoin gcoin = new GCoin();

        address[] memory arr = new address[](0);
        Treasury treasury = new Treasury(address(gcoin), msg.sender, arr, arr);

        gcoin.setTreasury(address(treasury));

        gcoin.addStableCoin(address(usdTest));

        GCoinStaking gCoinStaking = new GCoinStaking(address(gcoin), address(cgv), 10 minutes, 1);

        vm.stopBroadcast();

        string memory json = "json";
        vm.serializeAddress(json, "GCoin", address(gcoin));
        vm.serializeAddress(json, "Treasury", address(treasury));
        vm.serializeAddress(json, "CGV", address(cgv));
        vm.serializeAddress(json, "USDTest", address(usdTest));
        string memory finalJson = vm.serializeAddress(json, "GCoinStaking", address(gCoinStaking));
        string memory file = string.concat("./deploy/", network, ".json");
        vm.writeJson(finalJson, file);
        console.log("Contract addresses saved to %s", file);
    }
}
