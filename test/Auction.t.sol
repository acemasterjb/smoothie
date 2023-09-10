// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {Auction} from "../src/Auction.sol";
import {MockERC20} from "./MockERC20.sol";

// inspired by https://github.com/Philogy/create2-vickrey-contracts/blob/main/test/utils/BaseTest.sol
// og author: https://github.com/Philogy/
abstract contract BaseTest is Test {
    using LibString for uint256;

    bytes32 private _lastRandSeed = keccak256("some start seed");
    address[] internal _users;

    function _initUsers(uint256 _usersRequested) internal {
        _users = new address[](_usersRequested);
        for (uint256 i; i < _usersRequested; i++) {
            _users[i] = _genAddr();
            vm.label(_users[i], string(abi.encodePacked("user", i.toString())));
        }
    }

    function _genAddr() internal returns (address) {
        return _genAddr("");
    }

    function _genAddr(bytes memory _extraEntropy) internal returns (address newAddr) {
        newAddr = address(bytes20(keccak256(abi.encode(_nextRandSeed(), _extraEntropy, "genAddr"))));
    }

    function _nextRandSeed() private returns (bytes32 randSeed) {
        randSeed = _lastRandSeed;
        _lastRandSeed = keccak256(abi.encode(_lastRandSeed));
    }
}

contract TestAuction is Auction {
    constructor() Auction() {}
}

contract AuctionTest is BaseTest {
    address payable internal _auctionImplementation;
    MockERC20 internal _testToken;
    uint256 _now;

    function setUp() public {
        _initUsers(6);
        _auctionImplementation = payable(new TestAuction());
        _testToken = new MockERC20();
        _now = block.timestamp;
    }

    function testCantInitAgain() public {
        address auctioner = _users[0];
        Auction validAuction = _createAuction(address(_testToken), auctioner, 5e18 * 1e7, 0.004e18, 3600 * 24);

        vm.expectRevert();
        validAuction.initialize(address(_testToken), auctioner, 1, 1, 2);
    }

    // toDo: Mike Tyson - *this test is too big tbh tbh*
    function testBidding(uint256[5] memory bids, uint256[5] memory spotPrices) public {
        for (uint256 i = 1; i < 5; i++) {
            bids[i] = bound(bids[i], 1 ether, 100 ether);
            spotPrices[i] = bound(spotPrices[i], 1e6, 9e6);
        }

        address auctioner = _users[0];
        uint256 auctionDuration = 3600 * 24;
        Auction validAuction = _createAuction(address(_testToken), auctioner, 5e18 * 1e10, 0.004e18, auctionDuration);
        _testToken.mint(address(validAuction), 5e28);

        for (uint256 i = 1; i < 5; i++) {
            vm.deal(_users[i], bids[i]);
            vm.prank(_users[i]);
            validAuction.bid{value: bids[i]}(spotPrices[i], bids[i] * spotPrices[i]);
        }

        vm.warp(_now + 3600 * 24);
        uint256 lowestWinner = validAuction.reveal();
        console.log("lowest winner index: %i", lowestWinner);

        uint256 totalBids;
        for (uint256 i = 1; i < 5; i++) {
            vm.prank(_users[i]);
            if (validAuction.viewPendingTokens() == 0) continue;
            uint256 tokensPulled = validAuction.viewPendingTokens();
            totalBids += bids[i];
            vm.prank(_users[i]);
            validAuction.pullTokens();
            assertEq(_testToken.balanceOf(_users[i]), tokensPulled);
        }
        vm.prank(auctioner);
        validAuction.pullBids();
        assertEq(auctioner.balance, totalBids);

        for (uint256 i = 1; i < lowestWinner; i++) {
            if (validAuction.viewPendingRefunds(true) == 0) continue;
            vm.prank(_users[i]);
            validAuction.pullRefunds(true);

            assertEq(_users[i].balance, bids[i]);
        }
    }

    function _createAuction(
        address __testToken,
        address _owner,
        uint256 _targetSupply,
        uint256 _minBid,
        uint256 auctionDuration
    ) internal returns (Auction newAuction) {
        newAuction = Auction(payable(Clones.clone(_auctionImplementation)));
        newAuction.initialize(__testToken, _owner, _targetSupply, _minBid, auctionDuration);
    }
}
