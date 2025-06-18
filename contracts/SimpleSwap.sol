// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityToken.sol";

//interface MintableERC20 is LiquidityToken {
//    function mint(address to, uint256 amount) external;
//}

    struct Person{
        address id;
        uint256 amount1;  
        uint256 amount2;  
        uint256 liquidity;  
    }


contract SimpleSwap is Ownable {

    IERC20 public token1;
    IERC20 public token2;
    LiquidityToken public liquidityToken;
    //uint256 public price;

    constructor(address _token1, address _token2) Ownable(msg.sender) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        liquidityToken = new LiquidityToken();

    }        



/**** FUNCIONES EXTERNAS ****/


    // 0 PRUEBA

    function prueba(uint256 _amountUSDT) external {
        // approve
        token1.transferFrom(msg.sender, address(this), _amountUSDT);
    }

    function prueba2() external view returns (uint256 sup1, uint256 sup2){
        return (token1.totalSupply(), token2.totalSupply());
    }

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