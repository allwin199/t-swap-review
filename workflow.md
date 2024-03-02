# TSwap

- Tswap is v1 of uniswap
- It is a DEX(Decentralized Exchange)
- This project is meant to be a permissionless way for users to swap assets between each other at a fair price. You can think of T-Swap as a decentralized asset/token exchange (DEX). 

![t-swap-overview](./images/diagrams/t-swap-overview.png)

- A user has 10 USDC and this user wants to sell 10 USDC to buy 1 WETH
- Now this user has 0 USDC and 1 WETH

- T-Swap is known as an [Automated Market Maker (AMM)](https://chain.link/education-hub/what-is-an-automated-market-maker-amm) because it doesn't use a normal "order book" style exchange, instead it uses "Pools" of an asset. 
- It is similar to Uniswap. To understand Uniswap, please watch this video: [Uniswap Explained](https://www.youtube.com/watch?v=DLu35sIqVTM)

## Order Book Style Exchange

![classic-order-book](./images/diagrams/classic-order-book%20(1).png)

- UserA will come to the exchange and say I want 1 WETH for 10 USDC
- This trade will be placed on the order book
- Let's say UserB wants to take that trade
- UserB will place the trade of 1 WETH for 10 USDC 
- Order book will give 1 WETH to userA and give 10 USDC to UserB
- This order book style of trading is good for web2
- But when we try the same approach on Ethereum chain
- UserA has to place a transaction
- UserB has to place a transaction
- They both have to spend some gas
- Order book has to do some computations
- This could get expensive

## AMM (Automated Market Maker)

- Rather than placing orders and matching them as in an order book exchange, an AMM operates on the principle of liquidity pools.
- Let's visualize this using an example:
  - Assume two giant pools of money or 'liquidity pools' exist — one with `100 WETH` and the other with `1000 USDC`.
  - The ratio between them is `1:10`
  - Which means `1 WETH == 10 USDC` 
  - `User A` wishes to buy `1 WETH` with his `10 USDC`.

- At this stage, a specific mathematical function comes into play:
  - The system calculates the ratio of WETH to USDC in the pools which is 1000 USDC / 100 WETH = 10.
  - So, the 'mock price,' as we are calling it, is 1 WETH = 10 USDC.
  
- Now, if `User A` wants to take `1 WETH` out of the pool, he must ensure the correct ratio is maintained. So he puts `10 USDC` into the USDC pool, and only then can he take out `1 WETH`.

![01-amm](./images/diagrams/01-amm.png)

- This alters the ratio in the pools. 
- There are now `1010 USDC` and `99 WETH`. 
- Recalculating, we see the ratio is now `1010/99 = 10.2`. 
- Which means `1 WETH == 10.2 USDC` 
- An increase of 0.2 USDC from the last transaction. By simply completing the transaction, 
- User A has managed to move the market and change the price of WETH. 
- This essentially resembles market dynamics breath the concept of supply and demand; as demand for an asset increases, so does its price, and vice versa.
- Initially it had 100 WETH
- Now it has only 99 WETH
- Which means there is a demand for WETH if it continued on

- This same principle applies when User B wants to trade. 
- `UserB` wants trade `1 WETH`
- `1 WETH == 10.2 USDC`
- Therfore `UserB` will get `10.2 USDC`
- Poll reservoirs will get updated
- `WETH` pool will have `100 WETH`
- `USDC` pool will have `999.8 USDC`
- Therfore `1 WETH == 9.998 USDC`

![amm-final](./images/diagrams/final-amm.png)
  
- They can keep changing the ratios by adding or subtracting amounts in these pools to trade their preferred amount, given that the ratio always is maintained. 
- This AMM model is known as a `constant product market maker`, a type of AMM that maintains a constant product of the quantities of the two assets.
- The following code block presents an example of how this might be implemented programmatically:
- This demonstrates how an AMM operates in a simple and efficient manner, bypassing the traditional challenges of an order book model. But, it is important to remember that this simple example doesn't capture the complexity and potential risks associated with real-world AMMs.
- AMMs are just one aspect of DeFi that is pushing the boundaries of what is possible in finance, allowing individuals to gain control over their financial interactions. However, it’s crucial to understand that, like any financial system, it comes with its own set of risks and challenges. Remember, your capital is always at risk when investing.
- “The fascination of DeFi lies in the infinite possibilities it brings to the world of finance, pushing boundaries and creating opportunities.”

- `IMPORTANT`: Remember, almost all AMMs also extract a small fee for each transaction, say, `0.3%`. So, to trade `1 WETH`, one might actually need to send `1.03 WETH`, with the `0.03` WETH fee either going to its designated spot or staying within the pool.

### The Role Of Liquidity Providers

- Who funds these pools full of digital currencies, you ask? 
- Enter the Liquidity Providers (LPs), the unsung heroes of the AMM system. They supply the assets to the protocol so individuals can perform swaps.
- When an LP adds their funds - for example, 1000 USDC and 100 WETH - they gain ownership of the pool equivalent to their share of total funds, which is represented by Liquidity Provider Tokens `(LP Tokens)`.
- So, by investing their assets into the protocol, LPs not only gain ownership but also earn a share of the transaction fees generated from the trades.
- Let's say `LP1` adds their funds `1000 USDC and 100 WETH`
- `LP2` adds their funds `1000 USDC and 100 WETH`
- Pool will contain `2000 USDC` and `200 WETH`
- `LP1` will have `50%` ownsership of this pool
- `LP2` will have `50%` ownsership of this pool
- `50%` ownership will come in the form of token itself `(LP Tokens)`
- Let's say `LP1` and `LP2` has given `100 LP` tokens each
- which resembels thier `50%` share

- Let's say `LP3` adds their funds `500 USDC and 50 WETH`
- Pool will contain `2500 USDC` and `250 WETH`
- `500/2500 = 0.2 == 20%`
- `LP3` has `20%` ownership in the pool
- `LP3` will get `50 LP` tokens

### More About LP Tokens And Fees

- Let's investigate further into the LP Tokens and their relationship with fees. Say, a new liquidity provider, C, enters the pool with half of what A and B initially put in, essentially 500 USDC and 50 WETH. This, in turn, increases the total assets in the pool to 2500 USDC and 250 WETH.
- In return for their contribution, liquidity provider C receives LP tokens. How many?
- Well, we can calculate that by taking the ratio of the funds they've added to the total funds, in this case, 0.2 (or 20%). 
- Multiplying this by the total LP Tokens, we deduce that liquidity provider C will receive 50 LP Tokens, granted their contribution.
- Consequently, we now have a total of 250 LP Tokens in circulation. At this juncture, we also have a pool of 2500 USDC and 250 WETH ready for trades.

### How Fees Make Money For Liquidity Providers

- The burning question now is: How do liquidity providers make profits? 
- The answer lies with the transaction fees mentioned earlier.
- Every trade results in a fee that slightly adjusts the ratio of assets in the pool. 
- For instance, if a user trades 10 USDC for 1 WETH, they're also charged a fee (0.3 USDC in our example), 
- which changes the pool balances to `2510.3 USDC` and `249 WETH`.
  
- When a liquidity provider chooses to withdraw their funds, they can redeem their LP tokens for an amount of each pool asset proportional to their LP tokens. 
- So, if Liquidity Provider C withdraws their 50 LP Tokens (representing a 20% stake), they'll get back their original investment plus their earned fees.
- `LP3` will send back the `50 LP` tokens which is `20%` ownership
- They will get back the original investment with some fees
- let's calculte `20%` of the pool
- `20% of 2510.3 = 502.06 USDC`
- `20% of 249 = 49.8 WETH`
- Initially `LP3` invested `500 USDC` and `50 WETH`
- They got back `502.06 USDC` and `49.8 WETH` 
- Initially when they were investing `1 WETH == 10 USDC`
- `50 WETH == 500 USDC`
- `500 USDC + 500 USDC == 1000 USDC`
- They deposited 1000 USDC in total
- How much they got back
- `49.8 WETH == 498 USDC`
- `498 USDC + 502.06 USDC == 1000.06 USDC`
- By investing 1000 USDC they got back `1000.06` USDC
- `0.06` profit, after 1 transaction. If they pull out after 100 tx, this number will be big

```
# Assuming 1 WETH is equivalent to 10 USDC

# Initial Deposit: 500 USDC and 50 WETH

# Amount Withdrawn: 502.6 USDC and 49.8 WETH

# Equivalent to: 498 USDC + 502.6 USDC = 1000.6 USDC

# Profit: 1000.6 USDC - 1000 USDC = 0.6 USDC
```

- It's by these accruing transaction fees that liquidity providers gain returns on their investments. 
- The more trades executed, the more fees generated and the more money they make, providing an explanation regarding why so many are lured towards becoming liquidity providers.
















