// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../interfaces/IWETH.sol";

contract WETH is IWETH {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    // transfer
    function transfer(address to, uint value) public override returns (bool) {
        payable(to).transfer(value);
        return true;
    }

    function deposit() public payable override {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public override {
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
