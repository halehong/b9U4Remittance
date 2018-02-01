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
Personal note:
- The Exchange will withdraw the funds from Alice's contract by submitting the 2 passwords
- Passwords shall be sent over the Net encrypted already and shall match each other
- Passwords shall not be stored uncrypted in the blockchain
*/

/* 
--- Workflow ---
    Alice (depositor) deposits funds into the Remittance contract
        These funds shall include as well the commission that the Remittance contract will charge
    Alice requests a transfer hash key with the 2 passwords and the address of the chosen Exchange
        The required funds will be taken by the Remittance contract
        Alice can change her mind and cancel the Transfer. This will soft credit back her funds
    The Exchange account (Carol) will withdraw the funds by submitting the 2 passwords
        The Remittance contract will take the commission fees
        The transfer will be deleted
    Alice can withdraw any reminding funds
*/
import "./MyShared/Funded.sol";
    //is Funded includes as well:
    // - Owned
    // - Stoppable
    // Kill switch implemented in the Stoppable super contract
contract Remittance is Funded {
    uint private deadlineLimit;

    uint constant DEADLINELIMIT = 365 * 86400 / 15; // 2,102,40 = 1 year of blocks
    uint transferCommission;

    struct Transfer {
        address sender;
        uint amount;
        uint deadline;
    }
    mapping (bytes32 => Transfer) transfers; //hashKey => Transfer

        event LogRemittanceNew (address _sender, uint _deadlineLimit, uint _transferCommission);
        // Constructor
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

    function isExpired (bytes32 _hashKey) 
        constant
        public 
        returns(bool _isExpired) 
    {
        if (now > transfers[_hashKey].deadline)
            return true;
        else 
            return false;        
    }

        // Hashing function calculated with both passwords and the address of the exchange that we trust (_withdrawer)
        // --> Hashing with the exchange address ensures us that only the exchange will be able to withdraw the funds
        // PURE so the execution of this function doesn't go to the network but will be executed in our local copy
    function newTransferHashKey (address _withdrawer, bytes32 _pwdBeneficiary, bytes32 _pwdExchange)
        pure
        public
        returns (bytes32 _hashKey)
    {
        return keccak256 (_withdrawer, _pwdBeneficiary, _pwdExchange);
    }

        event LogRemittanceNewTransfer (address _sender, bytes32 _hashKey, uint _amount, uint _deadline);
        // Owner will use this function to register a new transaction to a beneficiary via an exchange
        // Reminder: Funded.sol provides the deposit and withdrawal functions for Owner
    function newTransfer (bytes32 _hashKey, uint _amount, uint _deadline)
        onlyIfRunning
        public
        returns (bool _success)
    {
        require (_amount > 0);

        require (_deadline > 0);
        require (_deadline <= deadlineLimit);

        transfers[_hashKey].amount = _amount; //regiter the NEW transfer
        transfers[_hashKey].deadline = now + _deadline;
        transfers[_hashKey].sender = msg.sender;

        spendFunds(_amount + transferCommission); //account the expenditure of the transfer to the depositor

        LogRemittanceNewTransfer (msg.sender, _hashKey, _amount, now + _deadline);
        return true;
    }

        event LogRemittanceRemoveTransfer (address _sender, bytes32 _hashKey);
        // Owner can decide to remove an existing registered transfer
    function removeTransfer (bytes32 _hashKey)
        onlyIfRunning
        public
        returns (bool _success)
    {
        softRefund(transfers[_hashKey].amount); //account a soft refund to the depositor
        delete transfers[_hashKey];

        LogRemittanceRemoveTransfer (msg.sender, _hashKey);
        return true;
    }

    function getTransfer (bytes32 _hashKey)
        constant
        public
        returns (uint _amount, uint _deadline)
    {
        return (transfers[_hashKey].amount, transfers[_hashKey].deadline);
    }

        event LogRemittanceWithdrawTransfer (address _sender, uint _transferAmount);
        // Function to be executed from the Exchange address to withdraw the Transfer funds
        // If the exchange sends the correct passwords, the resultant hash key will already exist in transfers mapping
    function withdrawTransfer (bytes32 _password1, bytes32 _password2)
        onlyIfRunning
        public
        returns (bool _success)
    {
        bytes32 withdrawalHashKey = newTransferHashKey (msg.sender, _password1, _password2); //the withdrawer address will be used to recalculate the hash key

        uint transferAmount = transfers[withdrawalHashKey].amount;
        require (transferAmount > 0); //prevent re-entry
        require (!isExpired(withdrawalHashKey)); //prevent withdrawal when expired
        require (getDepositorBalance(transfers[withdrawalHashKey].sender) >= transferAmount + transferCommission); //prevent over spending

        delete transfers[withdrawalHashKey]; //optimistic accounting
        msg.sender.transfer(transferAmount); //transfer to exchange
        getOwner().transfer(transferCommission); //transfer commission to owner

        LogRemittanceWithdrawTransfer (msg.sender, transferAmount);
        return true;
    }
}