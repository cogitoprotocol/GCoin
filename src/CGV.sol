// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

// Mock CGV for testing
contract CGV is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("CGVTest", "CGVTest") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
