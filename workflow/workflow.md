# TSwap

- Tswap is v1 of uniswap
- It is a DEX(Decentralized Exchange)
- This project is meant to be a permissionless way for users to swap assets between each other at a fair price. You can think of T-Swap as a decentralized asset/token exchange (DEX). 

![t-swap-overview](../images/diagrams/t-swap-overview.png)

- A user has 10 USDC and this user wants to sell 10 USDC to buy 1 WETH
- Now this user has 0 USDC and 1 WETH

- T-Swap is known as an [Automated Market Maker (AMM)](https://chain.link/education-hub/what-is-an-automated-market-maker-amm) because it doesn't use a normal "order book" style exchange, instead it uses "Pools" of an asset. 
- It is similar to Uniswap. To understand Uniswap, please watch this video: [Uniswap Explained](https://www.youtube.com/watch?v=DLu35sIqVTM)

[Read More About AMM](./amm-workflow.md)

## TSwap Pools

- The protocol starts as simply a `PoolFactory` contract. 
- This contract is used to create new "pools" of tokens. It helps make sure every pool token uses the correct logic. 
- But all the magic is in each `TSwapPool` contract. 

- You can think of each `TSwapPool` contract as it's own exchange between exactly 2 assets. 
- Any ERC20 and the [WETH](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) token. 
- These pools allow users to permissionlessly swap between an ERC20 that has a pool and WETH. 
- Once enough pools are created, users can easily "hop" between supported ERC20s. 

For example:
1. User A has 10 USDC
2. They want to use it to buy DAI
3. They `swap` their 10 USDC -> WETH in the USDC/WETH pool
4. Then they `swap` their WETH -> DAI in the DAI/WETH pool


![t-swap-with-factory](../images/diagrams/t-swap-with-factory.png)

Every pool is a pair of `TOKEN X` & `WETH`. 

There are 2 functions users can call to swap tokens in the pool. 
- `swapExactInput`
- `swapExactOutput`

## Liquidity Providers
- In order for the system to work, users have to provide liquidity, aka, "add tokens into the pool". 

### Why would I want to add tokens to the pool? 
- The TSwap protocol accrues fees from users who make swaps. Every swap has a `0.3` fee, represented in `getInputAmountBasedOnOutput` and `getOutputAmountBasedOnInput`. 
- Each applies a `997` out of `1000` multiplier. That fee stays in the protocol. 

- When you deposit tokens into the protocol,  you are rewarded with an LP token. You'll notice `TSwapPool` inherits the `ERC20` contract. 
- This is because the `TSwapPool` gives out an ERC20 when Liquidity Providers (LP)s deposit tokens. This represents their share of the pool, how much they put in. When users swap funds, 0.03% of the swap stays in the pool, netting LPs a small profit. 

### LP Example
1. LP A adds 1,000 WETH & 1,000 USDC to the USDC/WETH pool
   1. They gain 1,000 LP tokens
2. LP B adds 500 WETH & 500 USDC to the USDC/WETH pool 
   1. They gain 500 LP tokens
3. There are now 1,500 WETH & 1,500 USDC in the pool
4. User A swaps 100 USDC -> 100 WETH. 
   1. The pool takes 0.3%, aka 0.3 USDC.
   2. The pool balance is now 1,400.3 WETH & 1,600 USDC
   3. aka: They send the pool 100 USDC, and the pool sends them 99.7 WETH

Note, in practice, the pool would have slightly different values than 1,400.3 WETH & 1,600 USDC due to the math below. 

## Core Invariant 

Our system works because the ratio of Token A & WETH will always stay the same. Well, for the most part. Since we add fees, our invariant technially increases. 

`x * y = k`
- x = Token Balance X
- y = Token Balance Y
- k = The constant ratio between X & Y

```javascript
   y = Token Balance Y
   x = Token Balance X
   x * y = k
   x * y = (x + ∆x) * (y − ∆y)
   ∆x = Change of token balance X
   ∆y = Change of token balance Y
   β = (∆y / y)
   α = (∆x / x)

   Final invariant equation without fees:
   ∆x = (β/(1-β)) * x
   ∆y = (α/(1+α)) * y

   Invariant with fees
   ρ = fee (between 0 & 1, aka a percentage)
   γ = (1 - p) (pronounced gamma)
   ∆x = (β/(1-β)) * (1/γ) * x
   ∆y = (αγ/1+αγ) * y
```



















