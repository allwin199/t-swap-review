# Invariant

`x * y = k`
- x = Token Balance X
- y = Token Balance Y
- k = The constant ratio between X & Y

- The **Product** should always be the same
- `x * y` should always equal to `k` 

- Our system works because the ratio of Token A & WETH will always stay the same. Well, for the most part. 
- Since we add fees, our invariant technially increases. 
- Which means `k` technically increases


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

```js
   y = Token Balance Y
   x = Token Balance X
   x * y = k
```

- Token balance of X (let's say `weth`)
- Token balance of Y (let's say `DAI`)
- `x * y = k` should always hold

```js
   x * y = (x + ∆x) * (y − ∆y)
   ∆x = Change of token balance X
   ∆y = Change of token balance Y
```

- since users will deposit and withdraw there will be change in tokens
- `x * y = (x + ∆x) * (y − ∆y)`
- which means after a user performs a swap ratio should always stay the same
  
- Let's visualize this using an example:
  - Assume two giant pools of money or 'liquidity pools' exist — one with `100 WETH` and the other with `1000 USDC`.
  - The ratio between them is `1:10`
  - Which means `1 WETH == 10 USDC` 
  - `User A` wishes to buy `1 WETH` with his `10 USDC`.

  - Now, if `User A` wants to take `1 WETH` out of the pool, we must ensure the correct ratio is maintained. 
  - So he puts `10 USDC` into the USDC pool, and only then can he take out `1 WETH`.
  




