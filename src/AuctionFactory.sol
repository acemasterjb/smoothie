// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

import {Auction} from "./Auction.sol";

contract AuctionFactory is OwnableRoles {
    event AuctionCreated(address indexed auctionAddress, address indexed ownerAddress, uint256 deadline);

    address public immutable auctionImplementation;
    mapping(address => bool) auctionRegistry;

    constructor(address _auctionImplementation) {
        _initializeOwner(msg.sender);
        auctionImplementation = _auctionImplementation;
    }

    function createAuction(
        address auctioner,
        address auctionedToken,
        uint256 targetSupply,
        uint256 minBid,
        uint256 auctionDuration
    ) external returns (address newAuctionAddress) {
        require(auctionedToken != address(0), "AuctionFactory::createAuction: token can not be null.");
        require(targetSupply > 0, "AuctionFactory::createAuction: target supply too low");

        newAuctionAddress = Clones.clone(auctionImplementation);

        emit AuctionCreated(newAuctionAddress, auctioner, block.timestamp + auctionDuration);
        Auction(payable(newAuctionAddress)).initialize(auctionedToken, auctioner, targetSupply, minBid, auctionDuration);
    }
}
