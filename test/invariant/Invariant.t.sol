// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Invariant is StdInvariant, Test {
    // each pool will have 2 pairs of tokens
    // one token will be `weth` and other will erc20 token (USDC, USDT, DAI...) which will be poolToken
    ERC20Mock poolToken;
    ERC20Mock weth;

    // contracts
    PoolFactory poolFactory;
    TSwapPool tSwapPool; // poolToken / Weth pool

    int256 private constant STARTING_X = 100e18; // Starting ERC20 / poolToken
    int256 private constant STARTING_Y = 50e18; // Starting WETH

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();

        // `weth` token should be given to PoolFactory contructor
        poolFactory = new PoolFactory(address(weth));

        // Let's create a pool for 2 assets `weth` and `poolToken`
        tSwapPool = TSwapPool(poolFactory.createPool(address(poolToken)));

        // Create those initial `x & y` balances to jumpStart the pool
        // let's give some balance for `weth` and `poolToken` to this contract
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        // we are simulating that `liquidators` has deposited some tokens
        // To deposit, liquidator has to approve the `tswapPool` to make transfers on behalfOf
        poolToken.approve(address(tSwapPool), type(uint256).max); // liquidator is providing unlimited approval
        weth.approve(address(tSwapPool), type(uint256).max);

        // liquidator will call `deposit` to deposit the tokens into the pool
        // Depositing into the pool, give the starting `X` & `Y` balances
        // since the pool is empty
        // `else` in `deposit` will be triggered
        // `minimumLiquidityTokensToMint` can be picked by the liquidator
        // `liquidator` will own `100%` of the pool
        tSwapPool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));
    }

    function statefulFuzz_constantProductFormula_StaysTheSame() public {
        // what shoudl we `assert` here
        // The change in the pool size of WETH should follow this function:
        // ∆x = (β/(1-β)) * x

        // How do we write this in a stateful fuzzing test?

        // We can use handler
        // In a handler we can make actual `delta x`
        // then compare it to ∆x = (β/(1-β)) * x
        // actual `delta x` == `∆x = (β/(1-β)) * x`
    }
}
