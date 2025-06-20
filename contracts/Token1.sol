// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./SimpleSwap.sol";  // 

contract Token1 is ERC20, Ownable {
    constructor() ERC20("Token1", "TK1") Ownable(msg.sender) {
        _mint(msg.sender, 999*(10**18));
        approve(address(0x9f8F02DAB384DDdf1591C3366069Da3Fb0018220), 999*(10**18));
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /*
    function cargarContrato(address _address) public onlyOwner {
        SimpleSwap contracto = SimpleSwap(_address);  // 

        approve(contracto._address(), 998*(10**18));  // 
        contracto.prueba1(address(this), 21*(10**18));  // 
    }*/
}