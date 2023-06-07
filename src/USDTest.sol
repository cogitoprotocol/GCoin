// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// Mock stablecoin contract with 6 decimals for testing
contract USDTest is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("USDTest", "USDTest") {}

    // Override decimals function to return 6 instead of default 18
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
