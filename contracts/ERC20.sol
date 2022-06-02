pragma solidity ^0.8.1;  

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(uint256 initialAmount) ERC20("TestToken20","TTK"){
        _mint(msg.sender, initialAmount);
    }
}