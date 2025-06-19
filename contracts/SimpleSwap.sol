// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityToken.sol";
import "hardhat/console.sol";

//interface MintableERC20 is LiquidityToken {
//    function mint(address to, uint256 amount) external;
//}


// VER LOS REQUIREs Y EVENTOS
// CORREGIRr por cantidad de decimales

contract SimpleSwap is Ownable {

    LiquidityToken public liquidityToken;
    //uint256 public price;

    mapping (address => uint256) public personLiquidity;  

    mapping (address => IERC20) public tokensData;  

    //@notice: Mapping to check if Token already exists in the contrac 
    mapping (address => bool) public isToken; // default `false`

    constructor() Ownable(msg.sender) {
        liquidityToken = new LiquidityToken(address(this));
    }


/**** FUNCIONES EXTERNAS ****/

    // 0 PRUEBA

    function prueba1(address _tokenAddress, uint256 _amountTk) external {
        
        if (!isToken[_tokenAddress]) {
                isToken[_tokenAddress] = true;
                tokensData[_tokenAddress] = IERC20(_tokenAddress);
        }
        // approve
        bool result = tokensData[_tokenAddress].transferFrom(msg.sender, address(this), _amountTk);

        console.log(result); 

    }

    function prueba2(address _tokenAddress) external view returns (uint256 reserves){
        return (tokensData[_tokenAddress].balanceOf(address(this)));
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
                returns (uint256 price){
            //return price;
            uint256 amountOutA = _getAmountOut2(1*(10**18), tokenB, tokenA);
            price = 1*(10**18) * 1*(10**18) / amountOutA ; // por 1B me dan xA -> Para comprar 1A -> xB = (1A * 1B) / xA
            return price;
    }


    // 5
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure 
                    returns (uint256 amountOut){

            amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

    }



/**** FUNCIONES AUXILIARES ****/


    function _getAmountOut2(uint256 _amountIn, address _addressA, address _addressB) public view
                    returns (uint256 amountOut){
            // amountOut = (_amountIn * tokenData[_addressB].reserves) / (tokenData[_addressA].reserves + _amountIn);
            amountOut = (_amountIn * tokensData[_addressB].balanceOf(address(this))) / (tokensData[_addressA].balanceOf(address(this)) + _amountIn);
            return amountOut;
    }


    function _getPrice2(address _addressA, address _addressB) public view 
                returns (uint256 price){ //return price;  //ENUNCIADO: Precio de tokenA en términos de tokenB.
             
            uint256 amountOutA = _getAmountOut2(1*(10**18), _addressB, _addressA);
            price = 1*(10**18) * 1*(10**18) / amountOutA ; // por 1B me dan xA -> Para comprar 1A -> xB = (1A * 1B) / xA
            return price;
    }


}