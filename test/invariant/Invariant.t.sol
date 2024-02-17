// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { Handler } from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // these pools have 2 assets
    ERC20Mock poolToken;
    ERC20Mock weth;

    // we are gonna need the contracts
    PoolFactory poolFactory; // poolFactory can create many pools with 2 tokens
    TSwapPool tSwapPool; // This pool will contain (poolToken / wETH) tokens

    int256 constant STARTING_X = 100e18; // Starting ERC20 / poolToken
    int256 constant STARTING_Y = 50e18; // Starting WETH

    Handler handler;

    function setUp() external {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        poolFactory = new PoolFactory(address(weth));
        tSwapPool = TSwapPool(poolFactory.createPool(address(poolToken)));

        // Create those initial X & Y balances.
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        poolToken.approve(address(tSwapPool), type(uint256).max);
        weth.approve(address(tSwapPool), type(uint256).max);

        // Deposit into the pool, give the starting X & Y balances.
        tSwapPool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));

        handler = new Handler(tSwapPool);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    function statefulFuzz_constantProductFormula_StaysTheSameX() public {
        assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
    }

    function statefulFuzz_constantProductFormula_StaysTheSameY() public {
        assertEq(handler.actualDeltaY(), handler.expectedDeltaY());
    }
}
