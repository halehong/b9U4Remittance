var Remittance = artifacts.require("./Remittance.sol");

contract('Remittance', function(accounts) {
    var i;

    var owner = accounts[0];
    var alice = accounts[1];
    var bob = accounts[2];
    var carol = accounts[3];

    var commissionFunds = web3.toWei(0.01, "ether");
    var transferAmount = web3.toWei(2, "ether");

    var password1 = "123456";
    var password2 = "asd123";
    var hashTicketTransfer;

    beforeEach (() => {
        return Remittance.new(175200, commissionFunds, {from:owner}).then((instance) => {
          i = instance;
        });
    });

    
    it("Alice requests a hashTicket. Deposits for a new transfer. Cancels the transfer.", () => {
        let contractFundsBefore;
        let contractFundsAfter;

        console.log ("it: Alice requests a hashTicket. Deposits for a new transfer. Cancels the transfer.");

        contractFundsBefore = web3.eth.getBalance(i.address);
        console.log ("    Alice account balance = " + web3.fromWei(web3.eth.getBalance(alice), "ether"));
        console.log ("    Alice requests a hashTicket...");
        return i.newHashTicketTransferExchange.call (carol, password1, password2).then((r) => {
            hashTicketTransfer = r.toString();
            console.log ("    hashTicket = " + hashTicketTransfer);
            console.log ("    Alice deposits the funds for the transfer...");

            return i.depositFundsTransferExchange (hashTicketTransfer,0, {from: alice, value: transferAmount});

        }).then(() => {
            return i.getInfoTransfer.call(hashTicketTransfer);
        }).then((r) => {
            console.log ("      Transfer amount = " + web3.fromWei(r[0], "ether").toString());
            console.log ("      Transfer deadline = " + r[1].toString());
            assert.equal (+transferAmount, +r[0], "    ERROR: Transfer infor is not correct");
            return i.isDepositor.call (alice);
        }).then((r) => {
            console.log ("    Is Alice a depositor? " + r.toString());
            console.log ("    Alice account balance = " + web3.fromWei(web3.eth.getBalance(alice), "ether"));
            return i.getInfoDeposit.call(hashTicketTransfer);
        }).then((r) => {
            console.log ("    Alice deposit's balance = " + web3.fromWei(+r[1],"ether"));
            contractFundsAfter = web3.eth.getBalance(i.address);
            console.log ("    Contract balance = " + web3.fromWei(contractFundsAfter, "ether").toString(10));
            assert.isAbove(+contractFundsAfter, +contractFundsBefore, "ERROR: Funds for the contract shall have increased");
            contractFundsBefore = contractFundsAfter;
            console.log ("    Alice removes the transfer...");
        
            return  i.cancelTransferExchange (hashTicketTransfer, {from:alice});
        
        }).then(() => {
            return i.getInfoTransfer.call(hashTicketTransfer);
        }).then((r) => {
            console.log ("      Transfer amount = " + web3.fromWei(r[0], "ether").toString());
            console.log ("      Transfer deadline = " + r[1].toString());
            assert.equal (0, +r[0], "    ERROR: Transfer amount shall be 0 after cancellation");
            return i.isDepositor.call (alice);
        }).then((r) => {
            console.log ("    Is Alice a depositor? " + r.toString());
            console.log ("    Alice account balance = " + web3.fromWei(web3.eth.getBalance(alice), "ether"));
            return i.getInfoDeposit.call(hashTicketTransfer);
        }).then((r) => {
            console.log ("    Alice deposit's balance = " + web3.fromWei(+r[1],"ether"));
            contractFundsAfter = web3.eth.getBalance(i.address);
            console.log ("    Contract balance = " + web3.fromWei(contractFundsAfter, "ether").toString(10));
            assert.isBelow(+contractFundsAfter, +contractFundsBefore, "ERROR: Funds after shall be less than funds before");
        });
    });

    it("Alice requests a hashTicket. Deposits for a new transfer. Carol executes the transfer presenting 2 passwords.", () => {
        let contractFundsBefore;
        let contractFundsAfter;

        console.log ("it: Alice requests a hashTicket. Deposits for a new transfer. Carol executes the transfer presenting 2 passwords.");

        console.log ("    Alice requests a hashTicket...");
        return i.newHashTicketTransferExchange.call (carol, password1, password2).then((r) => {
            hashTicketTransfer = r.toString();
            console.log ("    hashTicket = " + hashTicketTransfer);
            console.log ("    Alice deposits the funds for the transfer...");

            return i.depositFundsTransferExchange (hashTicketTransfer,0, {from: alice, value: +transferAmount + +commissionFunds});

        }).then(() => {
            return i.getInfoTransfer.call(hashTicketTransfer);
        }).then((r) => {
            console.log ("      Transfer amount = " + web3.fromWei(r[0], "ether").toString());
            console.log ("      Transfer deadline = " + r[1].toString());
            assert.equal (+transferAmount + +commissionFunds, +r[0], "    ERROR: Transfer infor is not correct");
            contractFundsBefore = web3.eth.getBalance(i.address);
            console.log ("    Contract balance = " + web3.fromWei(contractFundsBefore, "ether").toString(10));
            return i.getInfoContractCommissions.call({from:owner});
        }).then((r) => {
            console.log ("    Contract commissions earned = " +web3.fromWei(r,"ether").toString());
            console.log ("    Carol account balance = " + web3.fromWei(web3.eth.getBalance(carol), "ether"));
            console.log ("    Carol executes the transfer...");
      
            return i.executeTransferToExchange (password1, password2, {from:carol});

        }).then(() => {
            console.log ("    Carol account balance = " + web3.fromWei(web3.eth.getBalance(carol), "ether"));
            contractFundsAfter = web3.eth.getBalance(i.address);
            console.log ("    Contract balance = " + web3.fromWei(contractFundsAfter, "ether").toString(10));
            assert.isBelow(+contractFundsAfter, +contractFundsBefore, "ERROR: Funds after shall be less than funds before");
            return i.getInfoContractCommissions.call({from:owner});
        }).then((r) => {
            console.log ("    Contract commissions earned = " +web3.fromWei(r,"ether").toString());
            assert.isAbove (+r, 0, "    ERROR: Commissions shall be more than 0");
        });
    });
});


/*
    function keccak256(...args) {
        args = args.map(arg => {
          if (typeof arg === 'string') {
            if (arg.substring(0, 2) === '0x') {
                return arg.slice(2)
            } else {
                return web3.toHex(arg).slice(2)
            }
          }

          if (typeof arg === 'number') {
            return leftPad((arg).toString(16), 64, 0)
          } else {
            return ''
          }
        })

        args = args.join('')

        return web3.sha3(args, { encoding: 'hex' })
      }
*/