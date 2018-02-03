pragma solidity ^0.4.4;

/*
Remittance
You will create a smart contract named Remittance whereby:

There are three people: Alice, Bob & Carol:
- Alice wants to send funds to Bob, but she only has ether & Bob wants to be paid in local currency.
luckily, Carol runs an exchange shop that converts ether to local currency.
- Therefore, to get the funds to Bob, Alice will allow the funds to be transferred through Carol's Exchange Shop. 
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
- add a deadline, after which Alice can claim back the unchallenged Ether
- add a limit to how far in the future the deadline can be
- add a kill switch to the whole contract
- plug a security hole (which one?) by changing one password to the recipient's address
- make the contract a utility that can be used by David, Emma and anybody with an address
- make you, the owner of the contract, take a cut of the Ethers smaller than what it would cost Alice to deploy the same contract herself
*/

/* 

Workflow:
- Sender requests a newHashTicketTransferExchange
- Sender deposits funds with the hash-ticket
- Exchange withdraws the funds providing the 2 passwords

Core functions:
- Constructor
- newHashTicketTransferExchange
- depositFundsTransferExchange
- cancelTransferExchange
- executeTransferToExchange

Support functions:
- isExpired
- getInfoTransfer

*/
import "./MyShared/FundsManager.sol";
    //is Funded includes as well:
    // - Owned
    // - Stoppable
contract Remittance is FundsManager {
    uint private deadlineLimit;
    uint constant DEADLINELIMIT = 365 * 86400 / 15; // 2,102,400 = 1 year of blocks
    uint constant DEFAULTDEADLINE = 175200; // 1 month
    uint public transferCommission;

    mapping (bytes32 => uint ) transfers; //hashTicket => deadline

// CORE FUNCTIONS

        event LogRemittanceNew (address _sender, uint _deadlineLimit, uint _transferCommission);
        // Constructor
        // If deadlineLimit is not provided the default is applied
    function Remittance (uint _deadlineLimit, uint _transferCommission)
        public
    {
        transferCommission = _transferCommission;

        if (_deadlineLimit == 0) 
            deadlineLimit = DEADLINELIMIT; // Default deadline
        else
            deadlineLimit = _deadlineLimit;

        LogRemittanceNew (msg.sender, _deadlineLimit, _transferCommission);
    }

        // This function "extends" the FundsManager.sol newHashTicket functions to support a 3rd party Exchange
        // The hash-ticket is calculated with both passwords and the address of the trusted exchange
        // --> Hashing with the exchange address ensures us that only the exchange will be able to withdraw the funds
        // PURE so the execution of this function doesn't go to the network but will be executed in our local copy
    function newHashTicketTransferExchange (address _exchange, bytes32 _pwdBeneficiary, bytes32 _pwdExchange)
        pure
        public
        returns (bytes32 _hashTicket)
    {
        return keccak256 (_exchange, _pwdBeneficiary, _pwdExchange);
    }

        event LogRemittanceDepositFundsTransferExchange (address _sender, bytes32 _hashTicket, uint _deadline);
        // This function "extends" FundsManager.sol depositFunds()
        // Adds deadline requirement. If none is provided the default deadline is applied
    function depositFundsTransferExchange (bytes32 _hashTicket, uint _deadline)
        onlyIfRunning
        payable
        public
        returns (bool _success)
    {       
        require(depositFunds (_hashTicket)); // FundsManager.sol function

        uint newTransferDeadline;
        
        if (_deadline == 0)
        {
            newTransferDeadline = DEFAULTDEADLINE;
        }
        else 
        {
            require (_deadline <= deadlineLimit);
            newTransferDeadline = _deadline;
        }

        transfers[_hashTicket] = now + newTransferDeadline;

        LogRemittanceDepositFundsTransferExchange (msg.sender, _hashTicket, now + _deadline);
        return true;
    }

        event LogRemittanceCancelTransferExchange (address _sender, bytes32 _hashTicket);
        // This function extends FundsManager.sol withdrawFunds()
        // Deletes deadline information
        // Transfers back to sender the funds
    function cancelTransferExchange (bytes32 _hashTicket)
        onlyDepositors
        onlyIfRunning
        public
        returns (bool _success)
    {
        require (_hashTicket != 0);

        delete transfers[_hashTicket];

        require (withdrawFunds(_hashTicket));

        LogRemittanceCancelTransferExchange (msg.sender, _hashTicket);
        return true;
    }

        event LogRemittanceExecuteTransferToExchange (address _sender, uint _transferAmount);
        // Function to be executed from the Exchange address to withdraw the Transfer funds
        // If the exchange sends the correct passwords, the resultant hash key will already exist in transfers mapping
    function executeTransferToExchange (bytes32 _password1, bytes32 _password2)
        onlyIfRunning
        public
        returns (bool _success)
    {
        bytes32 hashTicket = newHashTicketTransferExchange (msg.sender, _password1, _password2); //the withdrawer address will be used to recalculate the hash key
        
        address depositor;
        uint256 transferAmount;
        
        (depositor, transferAmount) = getInfoDeposit(hashTicket);
        require (transferAmount > 0); //prevent re-entry
        require (!isExpired(hashTicket)); //prevent withdrawal when expired
        
        chargeCommission(hashTicket, transferCommission); //charge Remittance contract's commission
        (depositor, transferAmount) = getInfoDeposit(hashTicket);

        delete transfers[hashTicket]; //optimistic accounting

        msg.sender.transfer(transferAmount); //transfer to exchange

        LogRemittanceExecuteTransferToExchange (msg.sender, transferAmount);
        return true;
    }

// SUPPORT FUNCTIONS

    function isExpired (bytes32 _hashTicket) 
        view
        public 
        returns(bool _isExpired) 
    {
        if (now > transfers[_hashTicket])
            return true;
        else 
            return false;        
    }

    function getInfoTransfer (bytes32 _hashTicket)
        view
        public
        returns (uint256 _amount, uint _deadline)
    {
        var(, amount) = getInfoDeposit(_hashTicket);
        return ( amount, transfers[_hashTicket]);
    }
}