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
 * Mints 1M CGV to TEST_WALLET
 */
contract DeployTestnetScript is Script {
    function run() external {
        string memory network = vm.envOr("NETWORK", string("localhost"));

        // TODO: Handle private keys better
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.envAddress("DEPLOYER");

        USDTest usdTest = new USDTest();

        CGV cgv = new CGV();
        cgv.mint(deployer, 1_000_000e6);

        GCoin gcoin = new GCoin();

        address[] memory arr = new address[](0);
        Treasury treasury = new Treasury(address(gcoin), msg.sender, arr, arr);
        cgv.mint(address(treasury), 10_000_000e6);

        gcoin.setTreasury(address(treasury));

        gcoin.addStableCoin(address(usdTest));

        treasury.approveFor(
            address(usdTest),
            address(gcoin),
            type(uint256).max
        );

        GCoinStaking gCoinStaking = new GCoinStaking(
            address(gcoin),
            address(cgv),
            100
        );
        gCoinStaking.setTreasury(address(treasury));
        treasury.approveFor(
            address(cgv),
            address(gCoinStaking),
            type(uint256).max
        );

        vm.stopBroadcast();

        string memory json = "json";
        vm.serializeAddress(json, "GCoin", address(gcoin));
        vm.serializeAddress(json, "Treasury", address(treasury));
        vm.serializeAddress(json, "CGV", address(cgv));
        vm.serializeAddress(json, "USDTest", address(usdTest));
        string memory finalJson = vm.serializeAddress(
            json,
            "GCoinStaking",
            address(gCoinStaking)
        );
        string memory file = string.concat("./deploy/", network, ".json");
        vm.writeJson(finalJson, file);
        console.log("Contract addresses saved to %s", file);
    }
}
