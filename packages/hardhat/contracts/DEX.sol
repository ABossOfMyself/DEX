// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <= 0.9.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


error Dex__Liquidity_already_exists_on_Dex();
error Dex__BAL_transfer_failed();
error Dex__ETH_amount_should_be_greater_than_Zero();
error Dex__Token_amount_should_be_greater_than_Zero();
error Dex__ETH_transfer_failed();
error Dex__You_do_not_have_required_Token_amount_in_the_Liquidity_Pool();


/**
 * @title DEX
 * @author ABossOfMyself
 * @notice A Minimum Viable Exchange.
 * @dev Created an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 */


contract DEX {

    /* ========== GLOBAL VARIABLES ========== */


    using SafeMath for uint256; // Outlines use of SafeMath for uint256 variables.


    IERC20 token; // Instantiates the imported contract.


    uint256 public totalLiquidity;


    /* ========== EVENTS ========== */


    /**
     * @notice Emitted when ethToToken() swap transacted.
     */

    event EthToTokenSwap(address user, string trade, uint256 ethDepositAmount, uint256 tokenReceivedAmount);


    /**
     * @notice Emitted when tokenToEth() swap transacted.
     */

    event TokenToEthSwap(address user, string trade, uint256 tokenDepositAmount, uint256 ethReceivedAmount);


    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */

    event LiquidityProvided(address user, uint256 liquidityMinted, uint256 ethDeposit, uint256 tokenDeposit);


    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */

    event LiquidityRemoved(address user, uint256 liquidityWithdrawn, uint256 ethRemoved, uint256 tokenRemoved);


    /* ========== MAPPINGS ========== */


    mapping(address => uint256) public liquidity;


    /* ========== CONSTRUCTOR ========== */


    constructor(address token_address) {

        token = IERC20(token_address); // Specifies the token address that will hook into the interface and be used through the variable 'token'.
    }


    /* ========== MUTATIVE FUNCTIONS ========== */


    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX.
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract.
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */


    function init(uint256 tokens) public payable returns(uint256) {

        if(totalLiquidity != 0) revert Dex__Liquidity_already_exists_on_Dex();
        

        totalLiquidity = address(this).balance;

        liquidity[msg.sender] = totalLiquidity;


        bool tokenSent = token.transferFrom(msg.sender, address(this), tokens);

        if(!tokenSent) revert Dex__BAL_transfer_failed();


        return totalLiquidity;
    }



    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta).
     */


    function price(uint256 xInput, uint256 xReserves, uint256 yReserves) public pure returns(uint256 yOutput) {

        uint256 xInputWithFee = xInput * 997;

        uint256 nominator = xInputWithFee * yReserves;

        uint256 denominator = xReserves * 1000 + xInputWithFee;

        return nominator / denominator;
    }



    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result.
     */


    function getLiquidity(address liquidityProvider) public view returns(uint256) {

        return liquidity[liquidityProvider];
    }



    /**
     * @notice sends Ether to DEX in exchange for $BAL.
     */


    function ethToToken() public payable returns(uint256 tokenOutput) {

        if(msg.value <= 0) revert Dex__ETH_amount_should_be_greater_than_Zero();


        uint256 ETH_Reserves = address(this).balance - msg.value;

        uint256 BAL_Reserves = token.balanceOf(address(this));


        tokenOutput = price(msg.value, ETH_Reserves, BAL_Reserves);


        token.approve(address(this), tokenOutput);

        bool tokenSent = token.transferFrom(address(this), msg.sender, tokenOutput);

        if(!tokenSent) revert Dex__BAL_transfer_failed();


        emit EthToTokenSwap(msg.sender, "ETH to Token", msg.value, tokenOutput);


        return tokenOutput;
    }



    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether.
     */


    function tokenToEth(uint256 tokenInput) public returns(uint256 ethOutput) {

        if(tokenInput <= 0) revert Dex__Token_amount_should_be_greater_than_Zero();


        uint256 ETH_Reserves = address(this).balance;

        uint256 BAL_Reserves = token.balanceOf(address(this));


        bool tokenSent = token.transferFrom(msg.sender, address(this), tokenInput);

        if(!tokenSent) revert Dex__BAL_transfer_failed();


        ethOutput = price(tokenInput, BAL_Reserves, ETH_Reserves);


        (bool ethSent, ) = msg.sender.call{value: ethOutput}("");

        if(!ethSent) revert Dex__ETH_transfer_failed();


        emit TokenToEthSwap(msg.sender, "Token to ETH", tokenInput, ethOutput);


        return ethOutput;
    }



    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool.
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */


    function deposit() public payable returns(uint256 BAL_Deposited) {

        if(msg.value <= 0) revert Dex__ETH_amount_should_be_greater_than_Zero();


        uint256 ETH_Reserves = address(this).balance - msg.value;

        uint256 BAL_Reserves = token.balanceOf(address(this));


        BAL_Deposited = msg.value * BAL_Reserves / ETH_Reserves;


        uint256 liquidityMinted = msg.value * totalLiquidity / ETH_Reserves;


        liquidity[msg.sender] += liquidityMinted; // Updating the mapping as user is depositing the funds so (+ plus) the token balance in his address mapping.


        totalLiquidity += liquidityMinted; // Updating the totalLiquidity as according to how much the user has deposited in terms of ETH, So that we can mint the BAL token according to it with the ratio of 1:1.



        bool tokenSent = token.transferFrom(msg.sender, address(this), BAL_Deposited);

        if(!tokenSent) revert Dex__BAL_transfer_failed();

    
        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, BAL_Deposited);


        return BAL_Deposited;
    }



    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool.
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */


    function withdraw(uint256 tokenAmount) public returns(uint256 ETH_Withdrawn, uint256 BAL_Withdrawn) {

        if(liquidity[msg.sender] < tokenAmount) revert Dex__You_do_not_have_required_Token_amount_in_the_Liquidity_Pool();


        uint256 ETH_Reserves = address(this).balance;

        uint256 BAL_Reserves = token.balanceOf(address(this));


        ETH_Withdrawn = tokenAmount * ETH_Reserves / totalLiquidity;
        
        BAL_Withdrawn = tokenAmount * BAL_Reserves / totalLiquidity;


        liquidity[msg.sender] -= tokenAmount; // Updating the mapping as user is withdrawing the funds so (- minus) the token balance from his address mapping.


        totalLiquidity -= tokenAmount; // Updating totalLiquidity as how much BAL Token the user has withdrawn from the totalLiquidity.


        (bool ethSent, ) = msg.sender.call{value: ETH_Withdrawn}("");

        if(!ethSent) revert Dex__ETH_transfer_failed();


        token.approve(address(this), BAL_Withdrawn);

        bool tokenSent = token.transferFrom(address(this), msg.sender, BAL_Withdrawn);

        if(!tokenSent) revert Dex__BAL_transfer_failed();


        emit LiquidityRemoved(msg.sender, tokenAmount, ETH_Withdrawn, BAL_Withdrawn);


        return (ETH_Withdrawn, BAL_Withdrawn);
    }
}