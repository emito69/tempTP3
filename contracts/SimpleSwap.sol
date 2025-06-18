// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface MintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract SimpleSwap is Ownable {

    ERC20 public token1;
    ERC20 public token2;
    //uint256 public price;

       constructor(address _token1, address _token2) Ownable(msg.sender) {
        token1 = ERC20(_token1);
        token2 = ERC20(_token2);
       }        




/**** FUNCIONES EXTERNAS ****/

    // 1
    function addLiquidityaddLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, 
                                      uint amountAMin, uint amountBMin, address to, uint deadline) external 
                                returns (uint amountA, uint amountB, uint liquidity){
        
    
    }


    // 2
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, 
                             uint amountAMin, uint amountBMin, address to, uint deadline) external 
                        returns (uint amountA, uint amountB){

    
    }


    // 3
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external 
                                returns (uint[] memory amounts){


    }


    // 4
    function getPrice(address tokenA, address tokenB) external view 
                returns (uint price){
            //return price;
    }


    // 5
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure 
                    returns (uint amountOut){

    }





}