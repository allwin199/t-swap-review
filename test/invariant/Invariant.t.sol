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
    }
}
