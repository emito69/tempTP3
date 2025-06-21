// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityToken.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


//interface MintableERC20 is LiquidityToken {
//    function mint(address to, uint256 amount) external;
//}


// VER LOS REQUIREs Y EVENTOS
// CORREGIRr por cantidad de decimales

contract SimpleSwap is Ownable {

    LiquidityToken private liquidityToken;
 
    mapping (address => IERC20) private tokensData;  
    
    mapping (bytes => LiquidityToken) private liqTokensData;  

    //@notice: Mapping to check if Token already exists in the contrac 
    mapping (address => bool) private isToken; // default `false`
    mapping (bytes => bool) private isTokensPair; // default `false`

    struct AddLiquidStruct {  // needed to declare this struct to solve "CompilerError: Stack too deep." 
        address tokenA;
        address tokenB;
        bytes20 temp1;
        bytes20 temp2;
        uint256 reserveA;
        uint256 reserveB;
        uint256 ratio1;
        uint256 ratio2;
        uint256 liqTemp;
        
    }

    AddLiquidStruct addLiquidStruct;

    uint256 MINIMUM_LIQUIDITY;

    constructor() Ownable(msg.sender) {
        
        MINIMUM_LIQUIDITY = 1*(10**6);

    }



/**** FUNCIONES EXTERNAS ****/

    // 1
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, 
                            uint amountAMin, uint amountBMin, address to, uint deadline) external 
                    returns (uint amountA, uint amountB, uint liquidity){
        
        require(tokenA != tokenB, "same tokens");
        //uint256 reserveA;
        //uint256 reserveB;

        /// a1) New Pool and TOkens Initialization Check 
        if (!isToken[tokenA]) {
                isToken[tokenA] = true;
                tokensData[tokenA] = IERC20(tokenA);
        }
        if (!isToken[tokenB]) {
                isToken[tokenB] = true;
                tokensData[tokenB] = IERC20(tokenB);
        }

        //bytes20 temp1 = bytes20(tokenA);
        addLiquidStruct.temp1 = bytes20(tokenA);
        //bytes20 temp2 = bytes20(tokenB);
        addLiquidStruct.temp2 = bytes20(tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        if (addLiquidStruct.temp1 >= addLiquidStruct.temp2){
            key = bytes.concat(addLiquidStruct.temp1, addLiquidStruct.temp2);
        }
        else{
            key = bytes.concat(addLiquidStruct.temp2, addLiquidStruct.temp1);
        }
        
        if (!isTokensPair[key]) {  //checks if the liquidity pool exists by looking at the pair's key
            isTokensPair[key] = true;
            liqTokensData[key] = new LiquidityToken(address(this));
            amountA = amountADesired;  // For new pools, uses exactly the amounts provided by the user
            amountB = amountBDesired;  // For new pools, uses exactly the amounts provided by the user
                                        // This sets the initial price ratio of the pool
              
        /// a2) or Existing Pool Calculation 
        }else { 
            // a) Get Current Reserves
            addLiquidStruct.reserveA = tokensData[tokenA].balanceOf(address(this));
            addLiquidStruct.reserveB = tokensData[tokenB].balanceOf(address(this));


            // b) Calculate Proportional Amounts and Determine Best Ratio
            uint256 amountBProportional = _getProportionalValue(amountADesired, addLiquidStruct.reserveA, addLiquidStruct.reserveB);
            console.log("amountBProportional: ", amountBProportional);
            if (amountBProportional <= amountBDesired) {
                require(amountBProportional >= amountBMin, "INSUFFICIENT_B_AMOUNT"); // Slippage Protection
                amountA = amountADesired;
                amountB = amountBProportional;
            } else {
                uint amountAProportional = _getProportionalValue(amountBDesired, addLiquidStruct.reserveB, addLiquidStruct.reserveA);
                console.log("amountAProportional: ", amountAProportional);
                assert(amountAProportional <= amountADesired);
                require(amountAProportional >= amountAMin, "INSUFFICIENT_A_AMOUNT");  // Slippage Protection
                amountA = amountAProportional;
                amountB = amountBDesired;
            }
        }

        // c) Token Transfer
        // approve
        bool statusA = _transferFrom(tokenA, msg.sender, address(this), amountA);
            if(!statusA){
                revert ("FAIL TRANSFER FROM TOKEN A TO LIQUIDITY");  
            }
        
        // approve
        bool statusB = _transferFrom(tokenB, msg.sender, address(this), amountB);
            if(!statusB){
                revert ("FAIL TRANSFER FROM TOKEN B TO LIQUIDITY");  
            }

        // d) Calculate equivalent Liquidity Tokens
        if (liqTokensData[key].totalSupply() == 0) {
            // √(amountA * amountB) is the geometric mean of the deposited amounts
            // MINIMUM_LIQUIDITY is 1000 wei (burned to prevent division by zero)
            
            liqTokensData[key].mint(address(this), MINIMUM_LIQUIDITY); // initial Liquidity
            addLiquidStruct.liqTemp = Math.sqrt(amountA*amountB) - MINIMUM_LIQUIDITY; // firts liquidity to emmmit
            
        }else {
            // min(amountA/reserveA, amountB/reserveB) * total L 

            //uint256 ratio1 = amountA/reserveA;
            addLiquidStruct.ratio1 = amountA/addLiquidStruct.reserveA;
            //uint256 ratio2 = amountB/reserveB;
            addLiquidStruct.ratio2 = amountB/addLiquidStruct.reserveB;
            //uint256 liqTemp;
            if (addLiquidStruct.ratio1 <= addLiquidStruct.ratio2) {
                addLiquidStruct.liqTemp = addLiquidStruct.ratio1 * liqTokensData[key].totalSupply();
            } else{
                addLiquidStruct.liqTemp = addLiquidStruct.ratio2 * liqTokensData[key].totalSupply();
            }
        }
        

        require(addLiquidStruct.liqTemp > 0, "INSUFFICIENT_LIQUIDITY");
        // e) Mint Liquidity Tokens

        liqTokensData[key].mint(to, addLiquidStruct.liqTemp);

        return (amountA, amountB, addLiquidStruct.liqTemp);

    }

    // 2
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external 
                        returns (uint amountA, uint amountB){

        /// a) Check for Existing Pool 
        //bytes20 temp1 = bytes20(tokenA);
        addLiquidStruct.temp1 = bytes20(tokenA);
        //bytes20 temp2 = bytes20(tokenB);
        addLiquidStruct.temp2 = bytes20(tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        if (addLiquidStruct.temp1 >= addLiquidStruct.temp2){
            key = bytes.concat(addLiquidStruct.temp1, addLiquidStruct.temp2);
        }
        else{
            key = bytes.concat(addLiquidStruct.temp2, addLiquidStruct.temp1);
        }

        require(isTokensPair[key], "Tokens-pair Pool do not exist");  //checks if the liquidity pool exists by looking at the pair's key              
        require((liquidity <= liqTokensData[key].balanceOf(msg.sender)), "INSUFFICIENT_LIQUIDITY");
        
        console.log("EMII BALANCE remove liquidity :", liquidity);
        
        /// b) Ammount Calculation 

        amountA = _getEffectiveLiquidOut(liquidity, tokenA, key);
        require(amountA >= amountAMin, "LESS_TokenA_THAN_amountAMin");  
        amountB = _getEffectiveLiquidOut(liquidity, tokenB, key);
        require(amountB >= amountBMin, "LESS_TokenB_THAN_amountBMin");  

        // c) Burn Tokens
        liqTokensData[key].burnFrom(msg.sender, liquidity);

        // d) Token Transfer
        // approve
        tokensData[tokenA].approve(address(this), amountA);

        console.log("EMII BALANCE remove amountA :", amountA);
        console.log("EMII BALANCE remove 00000000000A1 :", tokensData[tokenA].balanceOf(address(this)));
        console.log("EMII BALANCE remove 00000000000A2 :", tokensData[tokenA].allowance(address(this), address(this)));
        bool statusA = _transferFrom(tokenA, address(this), to, amountA);
        if(!statusA){
            revert ("FAIL trasnfer TOKEN A to DEST");  
        }

        console.log("EMII BALANCE remove 00000000000A3 :", tokensData[tokenA].balanceOf(to));

        // approve
        tokensData[tokenB].approve(address(this), amountB);

        
        console.log("EMII BALANCE remove amountB :", amountB);
        console.log("EMII BALANCE remove 00000000000B1 :", tokensData[tokenB].balanceOf(address(this)));
        console.log("EMII BALANCE remove 00000000000B2 :", tokensData[tokenB].allowance(address(this), address(this)));

        bool statusB = _transferFrom(tokenB, address(this), to, amountB);
        if(!statusB){
            revert ("FAIL trasnfer TOKEN B to DEST");  
        }

        console.log("EMII BALANCE remove 00000000000B3 :", tokensData[tokenB].balanceOf(to));

        return (amountA, amountB);
    }


    // 3
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external 
                                returns (uint[] memory amounts){

        /// a) Check for Existing Pool 
        addLiquidStruct.tokenA = address(path[0]);
        //console.log(addLiquidStruct.tokenA);

        addLiquidStruct.tokenB = address(path[1]);
        //console.log(addLiquidStruct.tokenB);

        //bytes20 temp1 = bytes20(tokenA);
        addLiquidStruct.temp1 = bytes20(addLiquidStruct.tokenA);
        //bytes20 temp2 = bytes20(tokenB);
        addLiquidStruct.temp2 = bytes20(addLiquidStruct.tokenB);

        // generate a unique key to identity pairs of tokens
        bytes memory key;
        if (addLiquidStruct.temp1 >= addLiquidStruct.temp2){
            key = bytes.concat(addLiquidStruct.temp1, addLiquidStruct.temp2);
        }
        else{
            key = bytes.concat(addLiquidStruct.temp2, addLiquidStruct.temp1);
        }

        require(isTokensPair[key], "Tokens-pair Pool do not exist");  //checks if the liquidity pool exists by looking at the pair's key              
        /// a2) Ammount Calculation 
        //console.log(addLiquidStruct.tokenA);
        //console.log(addLiquidStruct.tokenB);
        uint256 ammountOut = _getEffectiveAmountOut(amountIn, addLiquidStruct.tokenA, addLiquidStruct.tokenB);
        //console.log("EMIIII AMOUNT OUT: ", ammountOut);
        require(ammountOut >= amountOutMin, "LESS_TokenB_THAN_amountOutMin");  

        // c) Token Transfer
        // approve
        //tokensData[addLiquidStruct.tokenA].approve(address(this), amountIn);
        //console.log("EMII BALANCE swappp 00000000000A1:", tokensData[addLiquidStruct.tokenA].balanceOf(msg.sender));
        bool statusA = _transferFrom(addLiquidStruct.tokenA, msg.sender, address(this), amountIn);
            if(!statusA){
                revert ("FAIL trasnfer TOKEN A to CONTRACT");  
            }
        //console.log("EMII BALANCE swappp 00000000000A2:", tokensData[addLiquidStruct.tokenA].balanceOf(address(this)));      

        // approve
        tokensData[addLiquidStruct.tokenB].approve(address(this), ammountOut);
        //console.log("EMII BALANCE swappp 00000000000B1 :", tokensData[addLiquidStruct.tokenB].balanceOf(address(this)));
        //console.log("EMII BALANCE swappp 00000000000B2 :", tokensData[addLiquidStruct.tokenB].allowance(address(this), address(this)));
        bool statusB = _transferFrom(addLiquidStruct.tokenB, address(this), to, ammountOut);
            if(!statusB){
                revert ("FAIL trasnfer TOKEN B to CONTRACT");  
            }

        //console.log("EMII BALANCE swappp 00000000000B3 :", tokensData[addLiquidStruct.tokenB].balanceOf(to));

        uint256[] memory _amounts = new uint256[](2);
        _amounts[0]= amountIn;
        _amounts[1]= ammountOut;
        
        return amounts;
    }


    // 4
    function getPrice(address tokenA, address tokenB) external view 
                returns (uint256 price){
        require(isToken[tokenA], "TokenA not in this contract");
        require(isToken[tokenB], "TokenB not in this contract");
        
        //bool areTokens = (isToken[tokenA] && isToken[tokenB]);
        //require(areTokens, "Tokens address not existing in contract");
        price = tokensData[tokenB].balanceOf(address(this)) / tokensData[tokenA].balanceOf(address(this));  // Spot Price (Token A in terms of Token B) = reservesB/reservesA
        return price * 1e18;  // * 1e18 required in the Verification COntract

    }


    // 5
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
        // (senderLiquidity / totalSUPPLyL) * tokenRESERVES
        amountOut =( (_liquidity * tokensData[_token].balanceOf(address(this)) ) / liqTokensData[_key].totalSupply() );
        return amountOut;
    }


    // To maintain the proportion: amountA / amountB = reserveA / reserveB
    // Implement: (amountADesired * reserveB) / reserveA
    function _getProportionalValue(uint amountA, uint reserveA, uint reserveB) internal pure
                            returns (uint256 proportionalValue){       
        require(amountA > 0, "INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "INSUFFICIENT_LIQUIDITY");
        proportionalValue = amountA * reserveB / reserveA;  // amountB
    
    }

    function _getEffectivePrice(uint256 _amountIn, uint256 _amountOut) internal pure
                        returns (uint256 effectivePrice){
        //uint256 amountOut = _getAmountOut2(_amountIn, _addressA, _addressB);
        effectivePrice = _amountIn / _amountOut; // quantity of tokenA per tokenB
        return effectivePrice;
    }

    function _transferFrom(address token, address _from, address _to, uint256 _amount) internal returns (bool status){ 
       return status = tokensData[token].transferFrom(_from, _to, _amount);
    }

    function concatenate(bytes20 x, bytes20 y) internal pure returns (bytes memory) {
        return abi.encodePacked(x, y);
    }

    function pruebaLIQUID1(address _addressA, address _addressB) external view returns (uint256 data){

        bytes20 temp1 = bytes20(_addressA);
        bytes20 temp2 = bytes20(_addressB);
        // generate a unique key to identity for paris of tokens
        bytes memory key;
        if (temp1 >= temp2){
            key = bytes.concat(temp1, temp2);
        }
        else{
            key = bytes.concat(temp2, temp1);
        }
   
        data = liqTokensData[key].balanceOf(msg.sender);
        return data;   
    }

    function prueba11111(address _addressA, address _addressB) external 
            returns (address[] memory path) {
        bool result = _addressA == _addressB;
        //console.log("result 1 :", result);
        
        result = _addressA != _addressB;
        //console.log("result 2 :", result);

        isToken[_addressA] = true;
        isToken[_addressA] = false;

        bool areTokens = (isToken[_addressA] && isToken[_addressB]);

        //console.log("result 3 :", areTokens);

        address[] memory _path = new address[](2);
        _path[0] = _addressA;
        _path[1] = _addressB;

        /// a) Check for Existing Pool 
        //addLiquidStruct.tokenA = _path[0];
        //addLiquidStruct.tokenB = _path[1];

        console.log("AAAAAAAAAAAAAA :", addLiquidStruct.tokenA == _addressA);
        console.log("BBBBBBBBBBBBBB :", addLiquidStruct.tokenB == _addressB);

        return _path;
    }

}