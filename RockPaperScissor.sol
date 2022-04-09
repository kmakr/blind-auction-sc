// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract RockPaperScissor {

    uint256 constant public TIMEOUT = 5 minutes;
    address constant public BOB_ADDRESS = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address constant public ALICE_ADDRESS = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;

    address payable public playerOne;
    address payable public playerTwo;

    enum Choice {None, Rock, Paper, Scissors}
    enum Result {None, PlayerOne, PlayerTwo, Draw}  

    bytes32 private playerOneHashedChoice;
    bytes32 private playerTwoHashedChoice;

    Choice public playerOneRevealedChoice;
    Choice public playerTwoRevealedChoice;

    uint256 initialRevealTime;

    bool internal locked;


    modifier reentrancyGuard() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }
    
    modifier enoughFee() {
        require(msg.value >= 1 ether);
        _;
    }

    modifier registered() {
        require(msg.sender == playerOne || msg.sender == playerTwo);
        _;
    }

    modifier notRegistered() {
        require(msg.sender != playerOne && msg.sender != playerTwo);
        _;
    }

    modifier choiceLockedIn() {
        require(playerOneHashedChoice != 0x0 && playerTwoHashedChoice != 0x0);
        _;
    }

    modifier choiceRevealed() {
        require((playerOneRevealedChoice != Choice.None && playerTwoRevealedChoice != Choice.None) ||
               (initialRevealTime != 0 && block.timestamp > initialRevealTime + TIMEOUT));
        _;
    }

    function register() external payable enoughFee notRegistered returns(uint) {
        if (playerOne == address(0) && (msg.sender == BOB_ADDRESS || msg.sender == ALICE_ADDRESS)) {
            playerOne = payable(msg.sender);
            return 1;
        }
        else if (playerTwo == address(0) && (msg.sender == BOB_ADDRESS || msg.sender == ALICE_ADDRESS)) {
            playerTwo = payable(msg.sender);
            return 2;
        }
        return 0;
    }

    function play(bytes32 hashedChoice) external registered returns(bool) {
        if (msg.sender == playerOne && playerOneHashedChoice == 0x0) {
            playerOneHashedChoice = hashedChoice;
        }
        else if (msg.sender == playerTwo && playerTwoHashedChoice == 0x0) {
            playerTwoHashedChoice = hashedChoice;
        }
        else {
            return false;
        }
        return true;
    }

    function reveal(string memory plainMove, string memory salt) external registered choiceLockedIn returns(Choice) {
        bytes32 hashedChoice = sha256(abi.encodePacked(plainMove, salt));
        Choice choice = Choice(getFirstChar(plainMove));

        if (choice == Choice.None) {
            return Choice.None;
        }

        if (msg.sender == playerOne && playerOneHashedChoice == hashedChoice) {
            playerOneRevealedChoice = choice;
        }
        else if (msg.sender == playerTwo && playerTwoHashedChoice == hashedChoice) {
            playerTwoRevealedChoice = choice;
        }
        else {
            return Choice.None;
        }

        if (initialRevealTime == 0) {
            initialRevealTime = block.timestamp;
        }

        return choice;
    }

    function getResult() public choiceRevealed returns(Result) {
        Result result;

        if (playerOneRevealedChoice == playerTwoRevealedChoice) {
            result = Result.Draw;
        }
        else if ((playerOneRevealedChoice == Choice.Rock    && playerTwoRevealedChoice == Choice.Scissors)||
                (playerOneRevealedChoice == Choice.Paper    && playerTwoRevealedChoice == Choice.Rock)    ||
                (playerOneRevealedChoice == Choice.Scissors && playerTwoRevealedChoice == Choice.Paper)   ||
                (playerOneRevealedChoice != Choice.None     && playerTwoRevealedChoice == Choice.None)) {
            result = Result.PlayerOne;
        }
        else {
            result = Result.PlayerTwo;
        }

        address payable addrOne = playerOne;
        address payable addrTwo = playerTwo;
        restart();
        pay(result, addrOne, addrTwo);
        return result;
    }

    function pay(Result result, address payable playerOneAddr, address payable playerTwoAddr) private reentrancyGuard {
        if (result == Result.PlayerOne) {
            playerOneAddr.transfer(2 ether);
        }
        else if (result == Result.PlayerTwo) {
            playerTwoAddr.transfer(2 ether);
        }
        else if (result == Result.Draw) {
            playerOneAddr.transfer(1 ether);
            playerTwoAddr.transfer(1 ether);
        }
    }

    function restart() private {
        playerOne = payable(address(0));
        playerTwo = payable(address(0));
        playerOneHashedChoice = 0x0;
        playerTwoHashedChoice = 0x0;
        playerOneRevealedChoice = Choice.None;
        playerTwoRevealedChoice = Choice.None;
        initialRevealTime = 0;
    }

    // helper functions
    function getFirstChar(string memory str) private pure returns(uint) {
        bytes1 firstByte = bytes(str)[0];
        if (firstByte == 0x72) { 
            return 1; // "r" in "rock"
        } 
        else if (firstByte == 0x70) {
            return 2; // "p" in "paper"
        } 
        else if (firstByte == 0x73) {
            return 3; // "s" in "scissor"
        } 
        else {
            return 0; // none
        }
    }
}
