// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

interface IERC20 {
    function balanceOf(address owner) external returns (uint256 balance);
    function transferFrom(address _from, address _to, uint256 amount) external;
}

contract Auction is OwnableRoles {
    event OwnershipTransfered(address prevOwner, address newOwner);

    error NotOwner();
    error RevealOver();

    struct UserBid {
        address user;
        uint256 spotPrice;
        uint256 bidValue;
    }

    address public token;
    uint256 public minBid;
    bool public revealed;
    bool public thresholdReached;

    uint256 public revealTimestamp;
    uint256 private targetSupply; // secret
    uint256 private ethToBePulled;
    UserBid[] private userBids; // secret
    mapping(address => bool) private bidded; // secret
    mapping(address => uint256) private committedETH;
    mapping(address => uint256) private pendingETH;
    mapping(address => uint256) private pendingTokens;

    modifier inRevealPeriod() {
        if (revealed) revert RevealOver();
        _;
    }

    constructor() {
        // freeze implementation
        _setOwner(0x00000000000000000000000000000000DeaDBeef);
    }

    // auctionDuration should be in secs
    function initialize(address _token, address _owner, uint256 _targetSupply, uint256 _minBid, uint256 auctionDuration)
        external
    {
        require(owner() == address(0), "Auction::initialize: already initialized.");
        require(_owner != address(0), "Auction::initialize: `_owner` is null.");
        require(auctionDuration > 0, "Auction::initialize: `auctionDuration` too low.");

        _initializeOwner(_owner);
        revealTimestamp = block.timestamp + auctionDuration;
        targetSupply = _targetSupply;
        token = _token;

        minBid = _minBid;
    }

    // params need to be private
    // `spotPrice` needs to be in units/eth
    // perhaps `spotPrice` should have 6 decimals of precision
    function bid(uint256 spotPrice, uint256 numUnits) public payable inRevealPeriod {
        require(!bidded[msg.sender], "Auction::bid: User already bidded.");
        bidded[msg.sender] = true;

        require(numUnits > minBid, "Auction::bid: User needs to request more units than this.");
        require(spotPrice > 0, "Auction::bid: Spot price needs to be more than this.");

        uint256 cachedMsgValue = msg.value;
        require(spotPrice * cachedMsgValue >= numUnits, "Auction::bid: bad accounting.");

        // toDo: maybe add refund logic
        committedETH[msg.sender] += cachedMsgValue;

        UserBid memory userBid = UserBid(msg.sender, spotPrice, numUnits);
        userBids.push(userBid);
    }

    // this does not need to be private
    function reveal() public returns (uint256 indexOfLowestWinner) {
        require(
            IERC20(token).balanceOf(address(this)) >= targetSupply,
            "Auction::reveal: not enough tokens to allot to bidders"
        );
        indexOfLowestWinner = _sortBids();

        for (uint256 i = indexOfLowestWinner; i < userBids.length; i++) {
            ethToBePulled += committedETH[userBids[i].user];
            committedETH[userBids[i].user] = 0;
            pendingTokens[userBids[i].user] += userBids[i].bidValue;
        }

        revealed = true;
    }

    // this needs to be private
    function _sortBids() internal returns (uint256 indexOfLowestWinner) {
        indexOfLowestWinner = _sortBids(userBids);
    }

    function pullBids() public onlyOwner {
        require(revealed, "Auction::pullBids: reveal period not over.");

        (bool success,) = owner().call{value: ethToBePulled}("");
        require(success, "Auction::pullBids: ETH transfer failed.");
    }

    function viewPendingTokens() public view returns (uint256 _pendingTokens) {
        return pendingTokens[msg.sender];
    }

    function pullTokens() public {
        require(revealed, "Auction::pullTokens: reveal period not over.");
        require(pendingTokens[msg.sender] > 0, "Auction::pulltokens: bid has not been `reveal`ed or supplies ran out.");

        pendingTokens[msg.sender] = 0;
        IERC20(token).transferFrom(address(this), msg.sender, pendingTokens[msg.sender]);
    }

    function viewPendingRefunds(bool rageQuit) public view returns (uint256 _pendingRefunds) {
        if (rageQuit) {
            uint256 userCommittedETH = committedETH[msg.sender];
            _pendingRefunds += userCommittedETH;
        }

        _pendingRefunds += pendingETH[msg.sender];
    }

    function pullRefunds(bool rageQuit) public {
        require(bidded[msg.sender], "Auction::pullTokens: caller has not bidded in this auction.");

        address bidder = msg.sender;

        if (rageQuit) {
            uint256 userCommittedETH = committedETH[bidder];
            pendingETH[bidder] += userCommittedETH;
        }

        uint256 userPendingEth = pendingETH[bidder];
        pendingETH[bidder] = 0;

        (bool success,) = bidder.call{value: userPendingEth}("");
        require(success, "Auction::pullRefunds: ETH transfer failed.");
    }

    function _sortBids(UserBid[] storage _userBids) internal returns (uint256) {
        uint256 currentSupply;
        for (uint256 i = 0; i < _userBids.length; i++) {
            uint256 lowest = i;
            for (uint256 j = i + 1; j < _userBids.length; j++) {
                if (
                    _userBids[j].spotPrice * _userBids[j].bidValue
                        < _userBids[lowest].spotPrice * _userBids[lowest].bidValue
                ) {
                    lowest = j;
                }
            }

            // swap
            UserBid memory min = _userBids[i];
            _userBids[i] = _userBids[lowest];
            _userBids[lowest] = min;

            currentSupply += _userBids[i].bidValue;
            if (currentSupply >= targetSupply) {
                // index of lowest winner
                return i;
            }
        }

        return _userBids.length - 1;
    }

    receive() external payable {}
}
