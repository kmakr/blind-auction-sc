// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract BlindAuction {

    uint256 public constant BID_DURATION = 1 minutes;
    uint256 public constant REVEAL_DURATION = 1 hours;
    uint256 public bidEnd;
    uint256 public revealEnd;
    address payable public beneficiary;
    bool public isBidEnded;

    struct Bid {
        uint256 size;
        bytes32 hashedBid;
    }

    struct RevealedBid {
        uint256 size;
        address bidder;
    }
    
    RevealedBid[] public revealedBids;
    mapping(address => Bid[]) public bids;
    mapping(address => uint256) public refunds;

    uint256 public highestBidSize;
    address public highestBidder;

    bool internal locked;

    event AuctionResult(address auctionWinner, uint256 highestBidSize);
    

    modifier beforeTime(uint256 _time) { require(block.timestamp < _time, "invalid time"); _; }

    modifier afterTime(uint256 _time) { require(block.timestamp > _time, "invalid time"); _; }

    modifier reentrancyGuard() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    constructor(address payable _beneficiary) {
        beneficiary = _beneficiary;
        bidEnd = block.timestamp + BID_DURATION;
        revealEnd = bidEnd + REVEAL_DURATION;
    }

    function bid(bytes32 _hashedBid) external payable beforeTime(bidEnd) {
        bids[msg.sender].push(
            Bid({
                size: msg.value,
                hashedBid: _hashedBid
            })
        );
    }

    function reveal(uint256[] memory _bidSizes, bool[] memory _fakes, bytes32[] memory _secrets) external afterTime(bidEnd) beforeTime(revealEnd) {
        uint256 bidsLength = bids[msg.sender].length;

        require(_secrets.length == bidsLength, "invalid length of secrets");
        require(_bidSizes.length == bidsLength, "invalid length of bid sizes");
        require(_fakes.length == bidsLength, "invalid length of fakes");

        uint256 refundable;

        for (uint256 i = 0; i < bidsLength; i++) {
            Bid storage currentBid = bids[msg.sender][i];

            (uint256 bidSize, bool fake, bytes32 secret) = (_bidSizes[i], _fakes[i], _secrets[i]);

            // different hash value than the commited bid
            if (currentBid.hashedBid != keccak256(abi.encodePacked(bidSize, fake, secret))) {
                continue;
            }

            refundable += currentBid.size;

            if (currentBid.size >= bidSize && !fake) {
                // record real bids
                revealedBids.push(RevealedBid({
                    size: currentBid.size,
                    bidder: msg.sender
                }));

                if (checkBid(msg.sender, bidSize)) {
                    // current highest bid
                    refundable -= bidSize;
                }
            }


            // reset bid state
            currentBid.hashedBid = bytes32(0x0);
        }

        payable(msg.sender).transfer(refundable);
    }

    function checkBid(address bidder, uint256 size) internal returns(bool) {
        if (size <= highestBidSize) {
            return false;
        }

        if (highestBidder != address(0x0)) {
            refunds[highestBidder] += highestBidSize;
        }

        highestBidSize = size;
        highestBidder = bidder;

        return true;
    }

    function withdraw() external reentrancyGuard {
        uint256 withdrawableAmount = refunds[msg.sender];

        if (withdrawableAmount > 0) {
            // reset before sending
            refunds[msg.sender] = 0;
            payable(msg.sender).transfer(withdrawableAmount);
        }
    }

    function endAuction() external afterTime(revealEnd) {
        require(!isBidEnded, "bid has ended");
        isBidEnded = true;
        beneficiary.transfer(highestBidSize);
        emit AuctionResult(highestBidder, highestBidSize);
    }
}
