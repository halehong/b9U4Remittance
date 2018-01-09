pragma solidity ^0.4.4;

contract Remittance {
    address public owner;
    address public origin; //Alice
    address public beneficiary; //Bob
    address public exchange; //Carol

    bytes32 private password1; //two-factor authentication password 1
    bytes32 private password2;

    uint private funds; //the contract will store funds
    uint private deadLine; //after the deadline the funds are reverted back to origin

    function Remittance (address _origin, address _beneficiary, address _exchange, bytes32 _password1, bytes32 _password2) public {
        owner = msg.sender;
        origin = _origin;
        beneficiary = _beneficiary;
        exchange = _exchange;
        password1 = keccak256(_password1);
        password2 = keccak256(_password2);
        deadLine = now + 1000; //default deadline
    }

    function kill() onlyOwner public returns(bool) {
        selfdestruct(owner);
        return true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyOrigin() {
        require(msg.sender == origin);
        _;
    }

    modifier onlyExchange() {
        require (msg.sender == exchange);
        _;
    }

    function getPasswords() onlyOrigin public returns(bytes32 one, bytes32 two) {
        return (password1, password2);
    }

    function addFunds() public payable returns(bool) {
        funds += msg.value;
        return true;
    }

    function viewFunds() public returns(uint) {
        return funds;
    }

    function withdrawFunds(uint _amount) onlyOrigin public returns(bool) {
        require (funds >= _amount);
        owner.transfer(_amount);
        funds -= _amount;
        return true;
    }

    function setDeadLine(uint _extension) onlyOrigin public returns(uint) {
        require(_extension < 10000); //limit to avoid too far in the future deadlines
        deadLine = now + _extension;
        return deadLine;
    }

    function getDeadLine() public returns(uint) {
        return deadLine;
    }

    function checkDeadLine () public returns(uint) {
        if (now > deadLine) {
            origin.transfer(funds);
            return 0;
        } else {
            return deadLine;
        }
    }

    function fundsToExchange (bytes32 _password1, bytes32 _password2, uint _amount) onlyExchange public returns (bool) {
        require (checkDeadLine() > 0); //check we are before the deadline
        require (_password1 == password1); //check passwords
        require (_password2 == password2); 

        require(funds >= _amount); //check that the requested balance is available
        msg.sender.transfer(funds); //funds are transfered to the exchange account
        funds -= _amount; //if the transfer is successful then adjust the remaining funds
        return true;
    }

    function exchangeToBeneficiary () onlyExchange public payable returns(bool) {
        beneficiary.transfer(msg.value);
        return true;
    }
}