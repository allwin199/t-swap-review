/**
 * /-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\
 * |                                     |
 * \ _____    ____                       /
 * -|_   _|  / ___|_      ____ _ _ __    -
 * /  | |____\___ \ \ /\ / / _` | '_ \   \
 * |  | |_____|__) \ V  V / (_| | |_) |  |
 * \  |_|    |____/ \_/\_/ \__,_| .__/   /
 * -                            |_|      -
 * /                                     \
 * |                                     |
 * \-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/
 */
// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity 0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TSwapPool is ERC20 {
    error TSwapPool__DeadlineHasPassed(uint64 deadline);
    error TSwapPool__MaxPoolTokenDepositTooHigh(uint256 maximumPoolTokensToDeposit, uint256 poolTokensToDeposit);
    error TSwapPool__MinLiquidityTokensToMintTooLow(uint256 minimumLiquidityTokensToMint, uint256 liquidityTokensToMint);
    error TSwapPool__WethDepositAmountTooLow(uint256 minimumWethDeposit, uint256 wethToDeposit);
    error TSwapPool__InvalidToken();
    error TSwapPool__OutputTooLow(uint256 actual, uint256 min);
    error TSwapPool__MustBeMoreThanZero();

    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 private immutable i_wethToken;
    IERC20 private immutable i_poolToken;
    uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
    uint256 private swap_count = 0;
    uint256 private constant SWAP_COUNT_MAX = 10;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
    event LiquidityRemoved(address indexed liquidityProvider, uint256 wethWithdrawn, uint256 poolTokensWithdrawn);
    event Swap(address indexed swapper, IERC20 tokenIn, uint256 amountTokenIn, IERC20 tokenOut, uint256 amountTokenOut);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier revertIfDeadlinePassed(uint64 deadline) {
        if (deadline < uint64(block.timestamp)) {
            revert TSwapPool__DeadlineHasPassed(deadline);
        }
        _;
    }

    modifier revertIfZero(uint256 amount) {
        if (amount == 0) {
            revert TSwapPool__MustBeMoreThanZero();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        address poolToken,
        address wethToken,
        string memory liquidityTokenName,
        string memory liquidityTokenSymbol
    )
        ERC20(liquidityTokenName, liquidityTokenSymbol)
    {
        i_wethToken = IERC20(wethToken);
        i_poolToken = IERC20(poolToken);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD AND REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds liquidity to the pool
    /// @dev The invariant of this function is that the ratio of WETH, PoolTokens, and LiquidityTokens is the same
    /// before and after the transaction
    /// @param wethToDeposit Amount of WETH the user is going to deposit
    /// @param minimumLiquidityTokensToMint We derive the amount of liquidity tokens to mint from the amount of WETH the
    /// user is going to deposit, but set a minimum so they know approx what they will accept
    /// @param maximumPoolTokensToDeposit The maximum amount of pool tokens the user is willing to deposit, again it's
    /// derived from the amount of WETH the user is going to deposit
    /// @param deadline The deadline for the transaction to be completed by
    // e looked it
    function deposit(
        uint256 wethToDeposit,
        // LP tokens liquidator gets back for adding liquidity
        uint256 minimumLiquidityTokensToMint,
        // maximumPoolTokensToDeposit will be calculated based on the weth
        uint256 maximumPoolTokensToDeposit,
        // @audit-high `deadline` is not used
        // if someone sets a deadline, let's say, next block
        // even after the next block passes. They could still deposit
        // `deadline` is considered
        // IMPACT: `HIGH` a user who expects a deposit to fail, the deposit will go through regardless of the duration
        // This will lead to severe disruption of functionalitiy
        // LIKELIHOOD: `HIGH` anyone someone wants to deposit. The deadline will be always ignored
        // This will be always the case
        uint64 deadline
    )
        external
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
    {
        if (wethToDeposit < MINIMUM_WETH_LIQUIDITY) {
            // @audit-info MINIMUM_WETH_LIQUIDITY is a constant and therfore not required to be emitted
            revert TSwapPool__WethDepositAmountTooLow(MINIMUM_WETH_LIQUIDITY, wethToDeposit);
        }
        if (totalLiquidityTokenSupply() > 0) {
            uint256 wethReserves = i_wethToken.balanceOf(address(this));
            // @audit-gas don't need this line
            uint256 poolTokenReserves = i_poolToken.balanceOf(address(this));
            // Our invariant says weth, poolTokens, and liquidity tokens must always have the same ratio after the
            // initial deposit
            // poolTokens / constant(k) = weth
            // weth / constant(k) = liquidityTokens
            // aka...
            // weth / poolTokens = constant(k)
            // To make sure this holds, we can make sure the new balance will match the old balance
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) = constant(k)
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) =
            // (wethReserves / poolTokenReserves)
            //
            // So we can do some elementary math now to figure out poolTokensToDeposit...
            // (wethReserves + wethToDeposit) / poolTokensToDeposit = wethReserves
            // (wethReserves + wethToDeposit)  = wethReserves * poolTokensToDeposit
            // (wethReserves + wethToDeposit) / wethReserves  =  poolTokensToDeposit
            uint256 poolTokensToDeposit = getPoolTokensToDepositBasedOnWeth(wethToDeposit);
            // e if too many poolTokens is given as input
            // it will revert
            if (maximumPoolTokensToDeposit < poolTokensToDeposit) {
                revert TSwapPool__MaxPoolTokenDepositTooHigh(maximumPoolTokensToDeposit, poolTokensToDeposit);
            }

            // We do the same thing for liquidity tokens. Similar math.
            // e wethToDeposit = 10 WETH | totalLiquidityTokenSupply = 100 LP | wethReserves = 100 WETH
            // (10*100)/100 = 10 LP
            liquidityTokensToMint = (wethToDeposit * totalLiquidityTokenSupply()) / wethReserves;
            // e let's say we deposit 10 WETH and expect 10% of LP tokens which is 10LP `minimumLiquidityTokensToMint`
            // but after calculation if we get only `2%` of LP tokens
            // it dosen't meet the expected LP token, therfore revert
            if (liquidityTokensToMint < minimumLiquidityTokensToMint) {
                revert TSwapPool__MinLiquidityTokensToMintTooLow(minimumLiquidityTokensToMint, liquidityTokensToMint);
            }
            _addLiquidityMintAndTransfer(wethToDeposit, poolTokensToDeposit, liquidityTokensToMint);
        } else {
            // This will be the "initial" funding of the protocol. We are starting from blank here!
            // We just have them send the tokens in, and we mint liquidity tokens based on the weth
            _addLiquidityMintAndTransfer(wethToDeposit, maximumPoolTokensToDeposit, wethToDeposit);

            // `_addLiquidityMintAndTransfer` is making any external call
            // then it is updating a variable
            // but it is not a state variable in this case
            // @audit-info it would be better, if this was before `_addLiquidityMintAndTransfer`
            // to follow CEI
            liquidityTokensToMint = wethToDeposit;
        }
    }

    /// @dev This is a sensitive function, and should only be called by addLiquidity
    /// @param wethToDeposit The amount of WETH the user is going to deposit
    /// @param poolTokensToDeposit The amount of pool tokens the user is going to deposit
    /// @param liquidityTokensToMint The amount of liquidity tokens the user is going to mint
    function _addLiquidityMintAndTransfer(
        uint256 wethToDeposit,
        uint256 poolTokensToDeposit,
        uint256 liquidityTokensToMint
    )
        private
    {
        // follows CEI
        _mint(msg.sender, liquidityTokensToMint);
        // @audit-low `wethToDeposit` then `poolTokensToDeposit`
        // wrong order
        // this should be
        // (msg.sender, wethToDeposit, poolTokensToDeposit)
        // IMPACT: LOW - protocol is giving the wrong return/information
        // LIKELIHOOD: HIGH - always the case
        emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);

        // Interactions
        i_wethToken.safeTransferFrom(msg.sender, address(this), wethToDeposit);
        i_poolToken.safeTransferFrom(msg.sender, address(this), poolTokensToDeposit);
    }

    /// @notice Removes liquidity from the pool
    /// @param liquidityTokensToBurn The number of liquidity tokens the user wants to burn
    /// @param minWethToWithdraw The minimum amount of WETH the user wants to withdraw
    /// @param minPoolTokensToWithdraw The minimum amount of pool tokens the user wants to withdraw
    /// @param deadline The deadline for the transaction to be completed by
    function withdraw(
        uint256 liquidityTokensToBurn,
        uint256 minWethToWithdraw,
        uint256 minPoolTokensToWithdraw,
        uint64 deadline
    )
        external
        revertIfDeadlinePassed(deadline)
        revertIfZero(liquidityTokensToBurn)
        revertIfZero(minWethToWithdraw)
        revertIfZero(minPoolTokensToWithdraw)
    {
        // We do the same math as above
        // we are getting the ratio of `weth` and `pool` tokens based of `LP` tokens
        // If there is total of 100 LP tokens
        // and If you have 10 LP tokens then you have 10% of the pool
        // 10% of WETH
        // 10% of poolToken
        uint256 wethToWithdraw =
            (liquidityTokensToBurn * i_wethToken.balanceOf(address(this))) / totalLiquidityTokenSupply();
        uint256 poolTokensToWithdraw =
            (liquidityTokensToBurn * i_poolToken.balanceOf(address(this))) / totalLiquidityTokenSupply();

        // If a user wants to withdraw $1000 worth of WETH they deposited
        // but each price tanked and all their balance is now only $500 worth of WETH
        // now if they try to withdraw $1000 worth of WETH, it will revert
        // same scenario for pool tokens
        if (wethToWithdraw < minWethToWithdraw) {
            revert TSwapPool__OutputTooLow(wethToWithdraw, minWethToWithdraw);
        }
        if (poolTokensToWithdraw < minPoolTokensToWithdraw) {
            revert TSwapPool__OutputTooLow(poolTokensToWithdraw, minPoolTokensToWithdraw);
        }

        _burn(msg.sender, liquidityTokensToBurn);
        emit LiquidityRemoved(msg.sender, wethToWithdraw, poolTokensToWithdraw);

        i_wethToken.safeTransfer(msg.sender, wethToWithdraw);
        i_poolToken.safeTransfer(msg.sender, poolTokensToWithdraw);
    }

    /*//////////////////////////////////////////////////////////////
                              GET PRICING
    //////////////////////////////////////////////////////////////*/

    // @audit-info missing natspec
    // e this function will compute if we send `1 WETH` how much `DAI` will be sent back
    function getOutputAmountBasedOnInput(
        uint256 inputAmount,
        uint256 inputReserves,
        uint256 outputReserves
    )
        public
        pure
        revertIfZero(inputAmount)
        revertIfZero(outputReserves)
        returns (uint256 outputAmount)
    {
        // x * y = k
        // numberOfWeth * numberOfPoolTokens = constant k
        // k must not change during a transaction (invariant)
        // with this math, we want to figure out how many PoolTokens to deposit
        // since weth * poolTokens = k, we can rearrange to get:
        // (currentWeth + wethToDeposit) * (currentPoolTokens + poolTokensToDeposit) = k
        // **************************
        // ****** MATH TIME!!! ******
        // **************************
        // FOIL it (or ChatGPT): https://en.wikipedia.org/wiki/FOIL_method
        // (totalWethOfPool * totalPoolTokensOfPool) + (totalWethOfPool * poolTokensToDeposit) + (wethToDeposit *
        // totalPoolTokensOfPool) + (wethToDeposit * poolTokensToDeposit) = k
        // (totalWethOfPool * totalPoolTokensOfPool) + (wethToDeposit * totalPoolTokensOfPool) = k - (totalWethOfPool *
        // poolTokensToDeposit) - (wethToDeposit * poolTokensToDeposit)
        // @audit-info magic numbers
        uint256 inputAmountMinusFee = inputAmount * 997;
        uint256 numerator = inputAmountMinusFee * outputReserves;
        uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
        // the above 3 lines contribute to `0.3%` fees
        // users have to pay this `0.03%` fees
        // which will be given to the protocol and liquidity providers
        return numerator / denominator;
    }

    // @audit-info missing natspec
    // e this function will compute if we want `10 WETH` how much `DAI` have to be sent
    function getInputAmountBasedOnOutput(
        uint256 outputAmount,
        uint256 inputReserves,
        uint256 outputReserves
    )
        public
        pure
        revertIfZero(outputAmount)
        revertIfZero(outputReserves)
        returns (uint256 inputAmount)
    {
        // @audit-info magic numbers
        // @audit-high
        // 997/10_000 = 91.3% fee
        // actual 997/1_000 = 0.3% fee
        // IMPACT: HIGH - users are charged way too much in fees
        //LIKELIHOOD: HIGH - always the case `swapExactOutput` is one of the main swapping functions
        return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
    }

    // @audit-info natspec missing
    // e added natspec for better understanding
    /*
     * @notice figures out how much you need to input based on how much
     * output you want to receive.
     *
     * Example: You say "I want 1 DAI, and my input is WETH"
     * The function will figure out how much WETH you need to input to get 1 DAI
     * And then execute the swap
     * @param inputToken ERC20 token to pull from caller
     * @param outputToken ERC20 token to send to caller
     * @param outputAmount The exact amount of tokens to send to caller
     */
    function swapExactInput(
        IERC20 inputToken, // e input token to swap / sell ie: DAI
        uint256 inputAmount, // e amount of input token to sell ie: DAI
        IERC20 outputToken, // e output token to buy ie: WETH
        // e If we sell 10 DAI we expect to atleast 1 WETH
        // If it is less than 1 WETH it will revert
        uint256 minOutputAmount,
        // e deadline for when the transaction should expire
        uint64 deadline
    )
        // @audit-info can be marked as external
        public
        revertIfZero(inputAmount)
        revertIfDeadlinePassed(deadline)
        returns (
            // @audit-low unused variable
            // IMPACT : LOW - where protocol is giving the wrong return value
            // LIKELIHOOD: HIGH - always the case
            uint256 output
        )
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        uint256 outputAmount = getOutputAmountBasedOnInput(inputAmount, inputReserves, outputReserves);

        if (outputAmount < minOutputAmount) {
            revert TSwapPool__OutputTooLow(outputAmount, minOutputAmount);
        }

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }

    /*
     * @notice figures out how much you need to input based on how much
     * output you want to receive.
     *
     * Example: You say "I want 10 output WETH, and my input is DAI"
     * The function will figure out how much DAI you need to input to get 10 WETH
     * And then execute the swap
     * @param inputToken ERC20 token to pull from caller
     * @param outputToken ERC20 token to send to caller
     * @param outputAmount The exact amount of tokens to send to caller
     */
    // q why are we not getting the maximum input
    function swapExactOutput(
        IERC20 inputToken, // eg: DAI
        IERC20 outputToken, // weth
        uint256 outputAmount,
        uint64 deadline
    )
        // @audit-info missing `deadline` param in nat-spec
        public
        revertIfZero(outputAmount)
        revertIfDeadlinePassed(deadline)
        returns (uint256 inputAmount)
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        inputAmount = getInputAmountBasedOnOutput(outputAmount, inputReserves, outputReserves);

        // No slippage protection
        // let's say I want 10 output WETH and my input is DAI
        // right now price of 10 WETH is 1 DAI
        // we sent the transaction
        // but the pool get a massive transaction that changes the price
        // now the price of 10 WETH is 10 DAI
        // user will have to spend too much money
        // if they had a slippage protection like
        // maxInputAmount = 1 DAI
        // if(inputAmount > maxInputAmount){
        // revert();
        // }
        // @audit-high need a max input amount

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }

    /**
     * @notice wrapper function to facilitate users selling pool tokens in exchange of WETH
     * @param poolTokenAmount amount of pool tokens to sell
     * @return wethAmount amount of WETH received by caller
     */
    function sellPoolTokens(uint256 poolTokenAmount) external returns (uint256 wethAmount) {
        // @audit-high `swapExactInput` should be called instead of `swapExactOutput`
        return swapExactOutput(i_poolToken, i_wethToken, poolTokenAmount, uint64(block.timestamp));
    }

    /**
     * @notice Swaps a given amount of input for a given amount of output tokens.
     * @dev Every 10 swaps, we give the caller an extra token as an extra incentive to keep trading on T-Swap.
     * @param inputToken ERC20 token to pull from caller
     * @param inputAmount Amount of tokens to pull from caller
     * @param outputToken ERC20 token to send to caller
     * @param outputAmount Amount of tokens to send to caller
     */
    function _swap(IERC20 inputToken, uint256 inputAmount, IERC20 outputToken, uint256 outputAmount) private {
        if (_isUnknown(inputToken) || _isUnknown(outputToken) || inputToken == outputToken) {
            revert TSwapPool__InvalidToken();
        }

        // @audit-info breaks protocol invariant
        swap_count++;
        if (swap_count >= SWAP_COUNT_MAX) {
            swap_count = 0;
            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
        }
        emit Swap(msg.sender, inputToken, inputAmount, outputToken, outputAmount);

        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        outputToken.safeTransfer(msg.sender, outputAmount);
    }

    function _isUnknown(IERC20 token) private view returns (bool) {
        if (token != i_wethToken && token != i_poolToken) {
            return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                   EXTERNAL AND PUBLIC VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPoolTokensToDepositBasedOnWeth(uint256 wethToDeposit) public view returns (uint256) {
        uint256 poolTokenReserves = i_poolToken.balanceOf(address(this));
        uint256 wethReserves = i_wethToken.balanceOf(address(this));
        return (wethToDeposit * poolTokenReserves) / wethReserves;
    }

    /// @notice a more verbose way of getting the total supply of liquidity tokens
    function totalLiquidityTokenSupply() public view returns (uint256) {
        // q totalSupply of which token?
        // I guess pool token.. but not sure
        return totalSupply();
    }

    function getPoolToken() external view returns (address) {
        return address(i_poolToken);
    }

    function getWeth() external view returns (address) {
        return address(i_wethToken);
    }

    function getMinimumWethDepositAmount() external pure returns (uint256) {
        return MINIMUM_WETH_LIQUIDITY;
    }

    function getPriceOfOneWethInPoolTokens() external view returns (uint256) {
        return getOutputAmountBasedOnInput(
            1e18, i_wethToken.balanceOf(address(this)), i_poolToken.balanceOf(address(this))
        );
    }

    function getPriceOfOnePoolTokenInWeth() external view returns (uint256) {
        return getOutputAmountBasedOnInput(
            1e18, i_poolToken.balanceOf(address(this)), i_wethToken.balanceOf(address(this))
        );
    }
}
