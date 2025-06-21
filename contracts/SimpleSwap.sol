// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract SimpleSwap is Ownable {

    mapping (address => IERC20) private tokensData;  

    LiquidityToken private liquidityToken;
    mapping (bytes => LiquidityToken) private liqTokensData;  

    //@notice: Mapping to check if Token already exists in the contrac 
    mapping (address => bool) private isToken; // default `false`
    mapping (bytes => bool) private isTokensPair; // default `false`

    struct TempStruct {  // needed to declare this struct to solve "CompilerError: Stack too deep." 
        address tokenA;
        address tokenB;
        bytes20 temp1;
        bytes20 temp2;
        uint256 reserveA;
        uint256 reserveB;
        uint256 ratio1;
        uint256 ratio2;
        uint256 liqTemp;
        uint256 amountA;
        uint256 amountB;
    }

    TempStruct tempStruct;

    uint256 MINIMUM_LIQUIDITY;

/****   Modifiers / Requiers   *******/

/****   Events   *******/

    event AddLiquidity(address indexed from, address indexed to, address tokenA, address tokenB, uint amountA, uint amountB, uint liquidity);

    event RemoveLiquidity(address indexed from, address indexed to, address tokenA, address tokenB, uint amountA, uint amountB); 

    event SwapExactTokensForTokens(address indexed from, address indexed to, address tokenA, address tokenB, uint[] amounts); 

/****   CONSTRUCTOR   *******/
    constructor() Ownable(msg.sender) {
        MINIMUM_LIQUIDITY = 1*(10**6);
    }

/**** FUNCIONES EXTERNAS ****/

    // 1 - addLiquidity
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, 
                            uint amountAMin, uint amountBMin, address to, uint deadline) external 
                    returns (uint amountA, uint amountB, uint liquidity){
        
        require((block.timestamp <= deadline),"DEADLINE_PAST");
        require(tokenA != tokenB, "SAME_TOKENS");

        tempStruct.tokenA = tokenA;
        tempStruct.tokenB = tokenB;

        /// a1) New Pool and TOkens Initialization Check 
        if (!isToken[tokenA]) {
                isToken[tokenA] = true;
                tokensData[tokenA] = IERC20(tokenA);
        }
        if (!isToken[tokenB]) {
                isToken[tokenB] = true;
                tokensData[tokenB] = IERC20(tokenB);
        }

        /// a) Check for Existing Pool 
        tempStruct.temp1 = bytes20(tokenA);
        tempStruct.temp2 = bytes20(tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        key = _getKey(tempStruct.temp1, tempStruct.temp2);
        
        if (!isTokensPair[key]) {  //checks if the liquidity pool exists by looking at the pair's key
            isTokensPair[key] = true;
            liqTokensData[key] = new LiquidityToken(address(this));
            tempStruct.amountA = amountADesired;  // For new pools, uses exactly the amounts provided by the user
            tempStruct.amountB = amountBDesired;  // For new pools, uses exactly the amounts provided by the user
                                        // This sets the initial price ratio of the pool
              
        /// a2) or Existing Pool Calculation 
        }else { 
            // a) Get Current Reserves
            tempStruct.reserveA = tokensData[tokenA].balanceOf(address(this));
            tempStruct.reserveB = tokensData[tokenB].balanceOf(address(this));

            // b) Calculate Proportional Amounts and Determine Best Ratio
            uint256 amountBProportional = _getProportionalValue(amountADesired, tempStruct.reserveA, tempStruct.reserveB);
            if (amountBProportional <= amountBDesired) {
                require(amountBProportional >= amountBMin, "INSUFF_B_AMOUNT"); // Slippage Protection
                tempStruct.amountA = amountADesired;
                tempStruct.amountB = amountBProportional;
            } else {
                uint amountAProportional = _getProportionalValue(amountBDesired, tempStruct.reserveB, tempStruct.reserveA);
                assert(amountAProportional <= amountADesired);
                require(amountAProportional >= amountAMin, "INSUFF_A_AMOUNT");  // Slippage Protection
                tempStruct.amountA = amountAProportional;
                tempStruct.amountB = amountBDesired;
            }
        }

        // c) Token Transfer

        // approve - already given by msg.sender
        // transfer
        bool statusA = _transferFrom(tokenA, msg.sender, address(this), tempStruct.amountA);
            if(!statusA){
                revert ("FAIL TRANSF TOKEN A");  
            }
        
        // approve - already given by msg.sender
        // transfer
        bool statusB = _transferFrom(tokenB, msg.sender, address(this), tempStruct.amountB);
            if(!statusB){
                revert ("FAIL TRANSF TOKEN B");  
            }

        // d) Calculate equivalent Liquidity Tokens
        if (liqTokensData[key].totalSupply() == 0) {
            // √(amountA * amountB) is the geometric mean of the deposited amounts
            // MINIMUM_LIQUIDITY is 1000 wei (burned to prevent division by zero)
            
            liqTokensData[key].mint(address(this), MINIMUM_LIQUIDITY); // initial Liquidity
            tempStruct.liqTemp = Math.sqrt(tempStruct.amountA*tempStruct.amountB) - MINIMUM_LIQUIDITY; // firts liquidity to emmmit
            
        }else {
            // min(amountA/reserveA, amountB/reserveB) * total L 

            //uint256 ratio1 = amountA/reserveA;
            tempStruct.ratio1 = tempStruct.amountA/tempStruct.reserveA;
            //uint256 ratio2 = amountB/reserveB;
            tempStruct.ratio2 = tempStruct.amountB/tempStruct.reserveB;
            //uint256 liqTemp;
            if (tempStruct.ratio1 <= tempStruct.ratio2) {
                tempStruct.liqTemp = tempStruct.ratio1 * liqTokensData[key].totalSupply();
            } else{
                tempStruct.liqTemp = tempStruct.ratio2 * liqTokensData[key].totalSupply();
            }
        }
        
        require(tempStruct.liqTemp > 0, "INSUFF_LIQUIDITY");
        // e) Mint Liquidity Tokens

        liqTokensData[key].mint(to, tempStruct.liqTemp);

        emit AddLiquidity(msg.sender, to, tempStruct.tokenA, tempStruct.tokenB, tempStruct.amountA, tempStruct.amountB, tempStruct.liqTemp);

        return (tempStruct.amountA, tempStruct.amountB, tempStruct.liqTemp);

    }

    // 2 - removeLiquidity
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external 
                        returns (uint amountA, uint amountB){
        require((block.timestamp <= deadline),"DEADLINE_PAST");
        require(tokenA != tokenB, "SAME_TOKENS");

        /// a) Check for Existing Pool 
        tempStruct.temp1 = bytes20(tokenA);
        tempStruct.temp2 = bytes20(tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        key = _getKey(tempStruct.temp1, tempStruct.temp2);

        require(isTokensPair[key], "NOT_A_TKS_POOL");  //checks if the liquidity pool exists by looking at the pair's key              
        require((liquidity <= liqTokensData[key].balanceOf(msg.sender)), "INSUFF_LIQUIDITY");
        
       
        /// b) Ammount Calculation 

        amountA = _getEffectiveLiquidOut(liquidity, tokenA, key);
        require(amountA >= amountAMin, "TKA_<_Min");  
        amountB = _getEffectiveLiquidOut(liquidity, tokenB, key);
        require(amountB >= amountBMin, "TKB_<_Min");  

        // c) Burn Tokens
        liqTokensData[key].burnFrom(msg.sender, liquidity);

        // d) Token Transfer
        // approve
        tokensData[tokenA].approve(address(this), amountA);
        // transfer
        bool statusA = _transferFrom(tokenA, address(this), to, amountA);
        if(!statusA){
            revert ("FAIL_trasnf_TKA");  
        }

        // approve
        tokensData[tokenB].approve(address(this), amountB);
        // transfer
        bool statusB = _transferFrom(tokenB, address(this), to, amountB);
        if(!statusB){
            revert ("FAIL_trasnf_TKB");  
        }

        emit RemoveLiquidity(msg.sender, to, tokenA, tokenB, amountA, amountB); 

        return (amountA, amountB);
    }


    // 3 - swapExactTokensForTokens
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external 
                                returns (uint[] memory amounts){
        require((block.timestamp <= deadline),"DEADLINE_PAST");
        require(path[0] != path[1], "SAME_TOKENS");

        /// a) Check for Existing Pool 
        tempStruct.tokenA = path[0];
        tempStruct.tokenB = path[1];

        tempStruct.temp1 = bytes20(tempStruct.tokenA);
        tempStruct.temp2 = bytes20(tempStruct.tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        key = _getKey(tempStruct.temp1, tempStruct.temp2);

        require(isTokensPair[key], "NOT A TKS POOL");  //checks if the liquidity pool exists by looking at the pair's key              
        /// a2) Ammount Calculation 
        uint256 ammountOut = _getEffectiveAmountOut(amountIn, tempStruct.tokenA, tempStruct.tokenB);
        require(ammountOut >= amountOutMin, "TKB_<_Min");  

        // c) Token Transfer
        // approve - already given by msg.sender
        // transfer
        bool statusA = _transferFrom(tempStruct.tokenA, msg.sender, address(this), amountIn);
            if(!statusA){
                revert ("FAIL_trasnf_TKA");  
            }  

        // approve
        tokensData[tempStruct.tokenB].approve(address(this), ammountOut);
        // transfer
        bool statusB = _transferFrom(tempStruct.tokenB, address(this), to, ammountOut);
            if(!statusB){
                revert ("FAIL_trasnf_TKB");  
            }

        uint256[] memory _amounts = new uint256[](2);
        _amounts[0]= amountIn;
        _amounts[1]= ammountOut;
        
        emit SwapExactTokensForTokens(msg.sender, to, tempStruct.tokenA, tempStruct.tokenB, amounts); 

        return amounts;
    }


    // 4 - getPrice
    function getPrice(address tokenA, address tokenB) external view 
                returns (uint256 price){
        require(isToken[tokenA], "TKA_not_VALID");
        require(isToken[tokenB], "TKB_not_VALID");
        
        //bool areTokens = (isToken[tokenA] && isToken[tokenB]);
        //require(areTokens, "Tokens address not existing in contract");
        price = tokensData[tokenB].balanceOf(address(this)) / tokensData[tokenA].balanceOf(address(this));  // Spot Price (Token A in terms of Token B) = reservesB/reservesA
        return price * 1e18;  // * 1e18 required in the Verification COntract

    }


    // 5 - getAmountOut
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure 
                    returns (uint256 amountOut){
        
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);   
        //amountOut = reserveOut - ((reserveIn * reserveOut) / (reserveIn + amountIn))   // equivalent formula
        return amountOut;

    }




/**** FUNCIONES AUXILIARES ****/

    function _getEffectiveAmountOut(uint256 _amountIn, address _addressA, address _addressB) internal view
                    returns (uint256 amountOut){  
        amountOut = (_amountIn * tokensData[_addressB].balanceOf(address(this))) / (tokensData[_addressA].balanceOf(address(this)) + _amountIn);
        return amountOut;
    }

    function _getEffectiveLiquidOut(uint256 _liquidity, address _token, bytes memory _key) internal view
                    returns (uint256 amountOut){  
        // (senderLiquidity * tokenRESERVES ) / totalSUPPLyL 
        amountOut =( (_liquidity * tokensData[_token].balanceOf(address(this)) ) / liqTokensData[_key].totalSupply() );
        return amountOut;
    }

    // To maintain the proportion: amountA / amountB = reserveA / reserveB
    // Implement: (amountADesired * reserveB) / reserveA
    function _getProportionalValue(uint amountA, uint reserveA, uint reserveB) internal pure
                            returns (uint256 proportionalValue){       
        require(amountA > 0, "INSUFF_AMOUNT_TKA");
        require(reserveA > 0 && reserveB > 0, "INSUFF_LIQUIDITY");
        proportionalValue = amountA * reserveB / reserveA;  // amountB
    
    }

    function _getEffectivePrice(uint256 _amountIn, uint256 _amountOut) internal pure
                        returns (uint256 effectivePrice){
        effectivePrice = _amountIn / _amountOut; // quantity of tokenA per tokenB
        return effectivePrice;
    }

    function _transferFrom(address token, address _from, address _to, uint256 _amount) internal returns (bool status){ 
       return status = tokensData[token].transferFrom(_from, _to, _amount);
    }

    function _getKey(bytes20 _temp1, bytes20 _temp2) internal pure returns (bytes memory _key) {
        if (_temp1 >= _temp2){
            _key = bytes.concat(_temp1, _temp2);
        }
        else{
            _key = bytes.concat(_temp2, _temp1);
        }
    }

    function concatenate(bytes20 x, bytes20 y) internal pure returns (bytes memory) {
        return abi.encodePacked(x, y);
    }

}