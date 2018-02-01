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
- There shall be at least 2 contracts: Alice's Remittance and Carol's Exchange Shop
- The Exchange will withdraw the funds from Alice's contract by submitting the 2 passwords
- Passwords shall be sent over the Net encrypted already and shall match each other
- Passwords shall not be stored uncrypted in the blockchain
*/

import "./MyShared/Funded.sol";
    //is Funded includes as well:
    // - Owned
    // - Stoppable

    // Kill switch implemented in the Stoppable super contract

contract Remittance is Funded {
    // Alice's Remittance contract
    uint deadline;
    uint deadlineLimit;

    uint constant DEADLINELIMIT = 365 * 86400 / 15; // 2,102,40 = 1 year of blocks

    struct Transfer {
        uint amount;
        uint deadline;
    }
    mapping (bytes32 => Transfer) transfersWithExchange; //hashKey => Transfer

        event LogRemittanceNew (address _sender, uint _deadlineLimit);
        // Constructor
    function Remittance (uint _deadlineLimit)
        public
    {
        if (_deadlineLimit == 0) 
            deadlineLimit = DEADLINELIMIT; // Default deadline
        else
            deadlineLimit = _deadlineLimit;

        LogRemittanceNew (msg.sender, _deadlineLimit);
    }

    function isExpired (bytes32 _hashKey) 
        constant
        public 
        returns(bool _isExpired) 
    {
        if (now > transfersWithExchange[_hashKey].deadline)
            return true;
        else 
            return false;        
    }

        // PRIVATE
        // The function is CONSTANT so the call and return values are NOT sent to the network but executed in our local copy
        // --> This keeps this calculation "off-chain"
    function newHashKey (bytes32 _pwdBeneficiary, address _beneficiary, bytes32 _pwdExchange)
        pure
        private
        returns (bytes32 _hashKey)
    {
        return keccak256 (_pwdBeneficiary, _beneficiary, _pwdExchange);
    }

        // Public interface for newHashKey function
        // Limited to be executed only by the Owner
    function newTransferHashKey (bytes32 _pwdBeneficiary, address _beneficiary, bytes32 _pwdExchange)
        onlyOwner
        view
        public
        returns (bytes32 _hashKey)
    {
        return newHashKey (_pwdBeneficiary, _beneficiary, _pwdExchange);
    }

        event LogRemittanceNewTransferWithExchange (address _sender, bytes32 _hashKey, uint _amount, uint _deadline);
        // Owner will use this function to register a new transaction to a beneficiary via an exchange
        // Reminder: Funded.sol provides the deposit and withdrawal functions for Owner
    function newTransferWithExchange (bytes32 _hashKey, uint _amount, uint _deadline)
        onlyOwner
        onlyIfRunning
        public
        returns (bool _success)
    {
        require (_amount > 0);

        require (_deadline > 0);
        require (_deadline <= deadlineLimit);

        transfersWithExchange[_hashKey].amount = _amount; //regiter the NEW transfer
        transfersWithExchange[_hashKey].deadline = now + _deadline; 

        LogRemittanceNewTransferWithExchange (msg.sender, _hashKey, _amount, now + _deadline);
        return true;
    }

        event LogRemittanceRemoveTransferWithExchange (address _sender, bytes32 _hashKey);
        // Owner can decide to remove an existing registered transfer
    function removeTransferWithExchange (bytes32 _hashKey)
        onlyOwner
        public
        returns (bool _success)
    {
        delete transfersWithExchange[_hashKey];

        LogRemittanceRemoveTransferWithExchange (msg.sender, _hashKey);
        return true;
    }

    function getTransferWithExchange (bytes32 _hashKey)
        constant
        public
        returns (uint _amount, uint _deadline)
    {
        return (transfersWithExchange[_hashKey].amount, transfersWithExchange[_hashKey].deadline);
    }

        event LogRemittanceWithdrawFromExchange (address _sender, address _beneficiary, uint _withdrawalAmount);
        // Function to be executed from the Exchange address to withdraw the funds for the beneficiary
        // If the exchange sends the correct passwords and beneficiary address, the resultant hash key will already exist in our mapping
    function withdrawFromExchange (address _beneficiary, bytes32 _password1, bytes32 _password2)
        onlyIfRunning
        public
        returns (bool _success)
    {
        bytes32 withdrawalHashKey = newHashKey (_password1, _beneficiary, _password2); //calls the PRIVATE function

        uint withdrawalAmount = transfersWithExchange[withdrawalHashKey].amount;
        require (withdrawalAmount > 0); //prevent re-entry
        require (getContractBalance() >= withdrawalAmount); //prevent over spending
        require (!isExpired(withdrawalHashKey)); //prevent withdrawal when expired

        delete transfersWithExchange[withdrawalHashKey]; //optimistic accounting
        msg.sender.transfer(withdrawalAmount); //transfer to exchange

        LogRemittanceWithdrawFromExchange (msg.sender, _beneficiary, withdrawalAmount);
        return true;
    }
}