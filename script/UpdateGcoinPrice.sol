// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/GCoin.sol";
import "../src/Treasury.sol";
import "../src/USDTest.sol";

/**
 * Calculates the latest GCOIN price based on treasury value
 */
contract UpdateGcoinPrice is Script {
    using SafeMath for uint256;

    function run() external {
        string memory network = vm.envOr("NETWORK", string("localhost"));
        string memory root = vm.projectRoot();
        string memory file = string.concat(root, "/deploy/", network, ".json");
        string memory json = vm.readFile(file);

        address treasury = vm.parseJsonAddress(json, ".Treasury");
        USDTest usdTest = USDTest(vm.parseJsonAddress(json, ".USDTest"));
        GCoin gcoin = GCoin(vm.parseJsonAddress(json, ".GCoin"));

        uint256 balance = usdTest.balanceOf(treasury);
        uint256 supply = gcoin.totalSupply();
        uint256 price = balance
            .mul(10 ** gcoin.decimals())
            .div(10 ** usdTest.decimals())
            .mul(10 ** gcoin.decimals())
            .div(supply);

        console.log(
            "balance: %s, supply: %s, price: %s",
            balance,
            supply,
            price
        );

        // TODO: Handle private keys better
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        gcoin.updateGCoinValueManual(price);
        vm.stopBroadcast();
    }
}
