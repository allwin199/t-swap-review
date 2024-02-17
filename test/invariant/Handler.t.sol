// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool tSwapPool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    // Ghost Variables
    // The reason it is called ghost variables is, they don't exist in the actual contract.
    // They only exist in our Handler.
    int256 startingY;
    int256 startingX;

    int256 expectedDeltaY;
    int256 expectedDeltaX;
    int256 actualDeltaY;
    int256 actualDeltaX;

    address liquidityProvider = makeAddr("lp");

    constructor(TSwapPool _tSwapPool) {
        tSwapPool = _tSwapPool;
        weth = ERC20Mock(tSwapPool.getWeth());
        poolToken = ERC20Mock(tSwapPool.getPoolToken());
    }

    function deposit(uint256 wethAmount) public {
        // let's make sure it's a "reasonable" amount
        // avoid weird overflow errors
        wethAmount = bound(wethAmount, 0, type(uint64).max);

        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));

        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(tSwapPool.getPoolTokensToDepositBasedOnWeth(wethAmount));

        // deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(tSwapPool), type(uint256).max);
        poolToken.approve(address(tSwapPool), type(uint256).max);

        tSwapPool.deposit(wethAmount, 0, uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}
