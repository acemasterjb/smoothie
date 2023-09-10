# Smoothie 🍹

A Smooth Auction Solution.

## Description

Based on a [paper](https://arxiv.org/abs/2107.05853) (hereafter referred to as *the paper*) by Moshe Babaioff, Nicole Immorlica, Yingkai Li and Brendan Lucier.

This [smooth auction](https://www.tifr.res.in/~abhishek.sinha/files/Smooth_Games.pdf) implementation is meant to give significant, guaranteed welfare to a DAO looking to distribute its tokens to a limited number of investors.

It also reduces the likelihood of participants in the primary market from dumping in the secondary market at unreasonable rates.

## Limitations

**This repo right now is a WIP**.

This implementation is a WIP and only becomes a feasible solution, as spec'd by *the paper* **only when bidder transactions are private**, via a ZK solution like EY's [Nightfall](https://github.com/EYBlockchain/nightfall_3) or [Starlight](https://github.com/EYBlockchain/starlight).

This is because Ethereum L1 is a transparent chain that eliminates the game theoretical advantages of Smoothie (which is essentially a [Uniform-Price Auction](https://wikiless.tiekoetter.com/wiki/Multiunit_auction?lang=en#Uniform_price_auction) implementation).

This implementation right now also does not include the spot price threshold as specified in *the paper*, but it is required for **full "smoothness"** (right now it is only semi-smooth; see *the paper* for more).

## Deployment

### Prerequisites

- [foundry](https://book.getfoundry.sh/)

### Supported Networks

- Ethereum (Mainnet, Sapolia)
- Other EVM-compatible chains (networks other than local [anvil](https://book.getfoundry.sh/reference/anvil/) node yet to be tested).

---

1. Deploy the `Auction` implementation.

```console
$ forge create --rpc-url http://localhost:8545 --private-key $FORGE_PRIVATE_KEY src/Auction.sol:Auction
# ...
Deployed to: 0x840748F7Fd3EA956E5f4c88001da5CC1ABCBc038
# ...
```

The `Auction` implementation address (e.g. `0x840748F7Fd3EA956E5f4c88001da5CC1ABCBc038`) will need to be passed to the `AuctionFactory` constructor.

2. Deploy the `AuctionFactory`. Pass in the address of the `Auction` implementation to `--constructor-args`.

```console
# the address passed is an example
$ forge create --rpc-url http://localhost:8545 --private-key $FORGE_PRIVATE_KEY src/AuctionFactory.sol:AuctionFactory --constructor-args 0x840748F7Fd3EA956E5f4c88001da5CC1ABCBc038
# ...
Deployed to: 0x1bEfE2d8417e22Da2E0432560ef9B2aB68Ab75Ad
# ...
```
