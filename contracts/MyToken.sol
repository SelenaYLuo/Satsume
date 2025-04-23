// contracts/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "BUCK") {
        _mint(msg.sender, 300_000 * 10 ** 6);
    }

    // Override the decimals function to return 6
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
