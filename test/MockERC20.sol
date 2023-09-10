// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("PINEAPPLE", "IRE", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
