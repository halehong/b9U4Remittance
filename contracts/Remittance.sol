pragma solidity ^0.4.4;

/*
Remittance
You will create a smart contract named Remittance whereby:

there are three people: Alice, Bob & Carol.
Alice wants to send funds to Bob, but she only has ether & Bob wants to be paid in local currency.
luckily, Carol runs an exchange shop that converts ether to local currency.
Therefore, to get the funds to Bob, Alice will allow the funds to be transferred through Carol's Exchange Shop. Carol will convert the ether from Alice into local currency for Bob (possibly minus commission).

To successfully withdraw the ether from Alice, Carol needs to submit two passwords to Alice's Remittance contract: one password that Alice gave to Carol in an email and another password that Alice sent to Bob over SMS. Since they each have only half of the puzzle, Bob & Carol need to meet in person so they can supply both passwords to the contract. This is a security measure. It may help to understand this use-case as similar to a 2-factor authentication.

Once Carol & Bob meet and Bob gives Carol his password from Alice, Carol can submit both passwords to Alice's remittance contract. If the passwords are correct, the contract will release the ether to Carol who will then convert it into local funds and give those to Bob (again, possibly minus commission).

Of course, for safety, no one should send their passwords to the blockchain in the clear.

Stretch goals:
add a deadline, after which Alice can claim back the unchallenged Ether
add a limit to how far in the future the deadline can be
add a kill switch to the whole contract
plug a security hole (which one?) by changing one password to the recipient's address
make the contract a utility that can be used by David, Emma and anybody with an address
make you, the owner of the contract, take a cut of the Ethers smaller than what it would cost Alice to deploy the same contract herself

*/

contract Remittance {
    address public owner;
    address public origin; //Alice
    address public beneficiary; //Bob
    address public exchange; //Carol

    bytes32 private password1; //two-factor authentication password 1
    bytes32 private password2;

    uint private deadLine; //after the deadline the funds are reverted back to origin

    function Remittance (address _origin, address _beneficiary, address _exchange, bytes32 _password1, bytes32 _password2) public {
        owner = msg.sender;
        origin = _origin;
        beneficiary = _beneficiary;
        exchange = _exchange;
        password1 = _password1; //passwords shall come already encryted to avoid any unencrypted communication 
        password2 = _password2;
        deadLine = now + 1000; //default deadline
    }

    function kill() onlyOwner public {
        selfdestruct(owner);
    }

    function () public payable {}

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

    function viewFunds() public returns(uint) {
        return this.balance;
    }

    function withdrawFunds(uint _amount) onlyOrigin public returns(bool) {
        require (this.balance >= _amount);
        msg.sender.transfer(_amount);
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
            kill();
            return 0;
        } else {
            return deadLine;
        }
    }

    function fundsToExchange (bytes32 _password1, bytes32 _password2, uint _amount) onlyExchange public returns (bool) {
        require (checkDeadLine() > 0); //check we are before the deadline
        require (_password1 == password1); //check passwords
        require (_password2 == password2);

        require(this.balance >= _amount); //check that the requested balance is available
        msg.sender.transfer(_amount); //funds are transfered to the exchange account
        return true;
    }

    function exchangeToBeneficiary () onlyExchange public payable returns(bool) {
        beneficiary.transfer(msg.value);
        return true;
    }
}