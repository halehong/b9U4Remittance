pragma solidity ^0.4.4;
import "./Base.sol"; //inherit the Base contract

/*
Remittance
You will create a smart contract named Remittance whereby:

there are three people: Alice, Bob & Carol.
Alice wants to send funds to Bob, but she only has ether & Bob wants to be paid in local currency.
luckily, Carol runs an exchange shop that converts ether to local currency.
Therefore, to get the funds to Bob, Alice will allow the funds to be transferred through Carol's Exchange Shop. 
Carol will convert the ether from Alice into local currency for Bob (possibly minus commission).

To successfully withdraw the ether from Alice, Carol needs to submit two passwords to Alice's Remittance contract:
  - one password that Alice gave to Carol in an email
  - and another password that Alice sent to Bob over SMS.
Since they each have only half of the puzzle, Bob & Carol need to meet in person so they can supply both passwords to the contract. 
This is a security measure. It may help to understand this use-case as similar to a 2-factor authentication.

Once Carol & Bob meet and Bob gives Carol his password from Alice, Carol can submit both passwords to Alice's remittance contract. 
If the passwords are correct, the contract will release the ether to Carol who will then convert it into local
funds and give those to Bob (again, possibly minus commission).

Of course, for safety, no one should send their passwords to the blockchain in the clear.

Stretch goals:
add a deadline, after which Alice can claim back the unchallenged Ether
add a limit to how far in the future the deadline can be
add a kill switch to the whole contract
plug a security hole (which one?) by changing one password to the recipient's address
make the contract a utility that can be used by David, Emma and anybody with an address
make you, the owner of the contract, take a cut of the Ethers smaller than what it would cost Alice to deploy the same contract herself
*/

contract Remittance is Base {
    address private origin; //Alice
    address private beneficiary; //Bob
    address private exchange; //Carol

    bytes32 private password1; //two-factor authentication password 1
    bytes32 private password2;

    uint private deadLine; //after the deadline the funds are reverted back to origin
    uint private availableFunds; //total available funds
    uint private commissionFunds; //Origin shall deposit comission funds to be paid to exchange
    uint private commissionRequested; //store the commission requested by the exchange upon withdrawal
    uint private transferredAmount; //stores how much has been transferred to the exchange
    uint private transferredCommission; //stores how much has been transferred to the exchange as a commission

    event LogRemittanceNew(uint _deadLine);
    event LogRemittanceAddFunds(uint _amount, uint _availableFunds);
    event LogRemittanceWithdrawFunds(uint _amount, uint _availableFunds);
    event LogRemittanceAddCommissionFunds(uint _amount, uint _commissionToExchangeAmount);
    event LogRemittanceWithdrawCommissionFunds(uint _amount, uint _commissionToExchangeAmount);
    event LogRemittanceSetDeadLine (uint _newDeadLine);
    event LogRemittanceSendFundsToExchange (uint _amount);
    event LogRemittanceSendFundsFromExchangeToBeneficiary (uint _amount);
    event LogRemittanceSendCommissionToExchange (uint _commissionToTransfer);

    function Remittance (address _origin, address _beneficiary, address _exchange, bytes32 _password1, bytes32 _password2) public {
        origin = _origin;
        beneficiary = _beneficiary;
        exchange = _exchange;
        password1 = _password1; //passwords shall come already encryted to avoid any unencrypted communication
        password2 = _password2;
        deadLine = now + 1000; //default deadline

        LogRemittanceNew(deadLine);
    }

    modifier onlyOrigin() {
        require(msg.sender == origin);
        _;
    }

    modifier onlyExchange() {
        require (msg.sender == exchange);
        _;
    }

    function getTransferredAmount() public constant returns (uint _transferredAmount) {
        return transferredAmount;
    }

    function getTransferredCommission() public constant returns (uint _transferredCommission) {
        return transferredCommission;
    }

    function addFunds() onlyOrigin isNotPaused public payable returns(uint _availableFunds) {
        //
        // Add funds to the contract and keep accounting of them
        // Requires:
        //   - msg.sender == origin
        //   - Contract is not paused
        //
        availableFunds += msg.value;

        LogRemittanceAddFunds(msg.value, availableFunds);
        return availableFunds;
    }

    function withdrawFunds(uint _amount) onlyOrigin isNotPaused public returns(uint _availableFunds) {
        //
        // Function that allows origin to withdraw any submitted funds to adjust the quantity
        // Requires:
        //   - msg.sender == origin
        //   - Contract is not paused
        //   - _amount <= available funds
        //
        require (_amount <= availableFunds); //prevent re-entry

        availableFunds -= _amount; //optimistic accounting

        origin.transfer(_amount);

        LogRemittanceWithdrawFunds(_amount, availableFunds);
        return availableFunds;
    }

    function getAvailableFunds () isNotPaused public constant returns(uint _availableFunds) {
        return availableFunds;
    }

    function addCommissionFunds () onlyOrigin isNotPaused public payable returns(uint _commissionToExchangeAmount) {
        //
        // Function to add commission to exchange funds
        // Requires:
        //   - msg.sender == origin
        //   - Contract is not paused
        //
        commissionFunds += msg.value;

        LogRemittanceAddCommissionFunds(msg.value, commissionFunds);
        return commissionFunds;
    }

    function withdrawCommissionFunds (uint _amount) onlyOrigin isNotPaused public returns(uint _commissionToExchangeAmount) {
        //
        // Function that allows origin to withdraw any submitted funds to adjust the quantity
        // Requires:
        //   - msg.sender == origin
        //   - Contract is not paused
        //   - _amount <= available commisions funds
        //   - commissionFunds - _amount >= commissionRequested to prevent not having enough commission funds to pay the already promissed commission
        //
        require (_amount <= commissionFunds); //prevent re-entry
        require (commissionFunds - _amount >= commissionRequested);

        commissionFunds -= _amount; //optimistic accounting

        origin.transfer(_amount);

        LogRemittanceWithdrawCommissionFunds(_amount, commissionFunds);
        return commissionFunds;
    }

    function getCommissionFunds () isNotPaused public constant returns(uint _commissionToExchangeAmount) {
        return commissionFunds;
    }

    function setDeadLine(uint _extension) onlyOrigin isNotPaused public returns(uint _deadLine) {
        //
        // Function to set the deadline to any point in the future
        // Requires:
        //   - msg.sender == origin
        //   - Contract is not paused
        //   - _extension < 10000 to prevent too far in the future deadlines
        //
        require(_extension < 10000);

        deadLine = now + _extension;

        LogRemittanceSetDeadLine (deadLine);
        return deadLine;
    }

    function checkDeadLine () public returns(uint _deadline) {
        if (now > deadLine) {
            pause(); //if the deadline is passed, pause the contract
            return 0;
        } else {
            return deadLine;
        }
    }

    modifier isNotExpired () {
        require(checkDeadLine() > 0);
        _;
    }

    function sendFundsToExchange (bytes32 _password1, bytes32 _password2, uint _commission) onlyExchange isNotPaused isNotExpired public returns (bool _success) {
        //
        // Send the requested amount to the exchange account
        // Requires:
        //   - msg.sender == exchange account
        //   - Contract is not paused
        //   - Deadline not expired
        //   - Funds shall not be already sent to the exchange. Prevents re-entry
        //   - There are funds to send
        //   - The commissions amount stored in the contract are enough to pay the exchange
        //   - Submitted passwords to match stored passwords
        //
        require (transferredAmount == 0); //prevent re-entry
        require (availableFunds > 0); //there are funds to send
        require (commissionFunds >= _commission); //check that the required commission is avaialble

        require (_password1 == password1); //check passwords
        require (_password2 == password2); //check passwords

        commissionRequested = _commission; //store the requested commission for later verification
        transferredAmount = availableFunds; //optimistic accounting
        availableFunds = 0;

        exchange.transfer(transferredAmount);

        LogRemittanceSendFundsToExchange (transferredAmount);
        return true;
    }

    function sendFundsFromExchangeToBeneficiary () onlyExchange isNotPaused public payable returns(bool _success) {
        //
        // Sends the
        // Requires:
        //   - msg.sender == exchange account
        //   - Contract is not paused
        //   - The commissions has not been already paid. Prevents re-entry
        //   - The commissions amount stored in the contract are enough to pay the exchange
        //
        require (transferredCommission == 0); //prevent re-entry
        require (commissionFunds >= commissionRequested); //ensure enough commission funds

        transferredCommission = commissionRequested; //optimistic accounting
        commissionFunds -= commissionRequested;

        beneficiary.transfer(msg.value); //As the transfer is in another currency we cannot check the amount to be transferred
        exchange.transfer(commissionRequested);

        LogRemittanceSendFundsFromExchangeToBeneficiary (msg.value);
        LogRemittanceSendCommissionToExchange (commissionRequested);
        return true;
    }
}