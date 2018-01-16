var Remittance = artifacts.require("./Remittance.sol");

contract('Remittance', function(accounts) {
    var instance;

    var owner = accounts[0];
    var alice = accounts[1];
    var bob = accounts[2];
    var carol = accounts[3];

    var password1 = web3.sha3("123456", { encoding: 'hex' });
    var password2 = web3.sha3("asd123", { encoding: 'hex' });

    before (() => {
        return Remittance.new(alice, bob, carol, password1, password2, {from:owner}).then((i) => {
          instance = i;
        });
    });

    it("Alice sends funds", () => {
        let fundsBefore;

        console.log("it:Alice sends funds to the contract");

        return instance.getAvailableFunds.call().then((r) => {
            fundsBefore = r;
            console.log("  Contract funds before = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.addFunds({from:alice, value:web3.toWei(0.2, "ether")});
        }).then(() => {
            return instance.getAvailableFunds.call();
        }).then((r) => {
            console.log("  Contract funds after = " + web3.fromWei(r,"ether").toString(10));
            assert.isBelow(+fundsBefore, +r, "ERROR: funds after are not greater than funds before");
        });
    });

    it("Alice withdraws funds", () => {
        let fundsBefore;

        console.log("it:Alice withdraws funds");

        return instance.getAvailableFunds.call().then((r) => {
            fundsBefore = r;
            console.log("  Contract funds before = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.withdrawFunds(web3.toWei(0.05, "ether"), {from:alice});
        }).then(() => {
            return instance.getAvailableFunds.call();
        }).then((r) => {
            console.log("  Contract funds after = " + web3.fromWei(r,"ether").toString(10));
            assert.isAbove(+fundsBefore, +r, "ERROR: Contract funds before are not greater than funds after");
        });
    });

    it("Check deadline is still valid", () => {
        console.log("it:Check deadline is still valid");
        return instance.checkDeadLine.call().then((r) => {
            if (r == 0) {
                return instance.setDeadLine.call(1000).then((r) => {
                console.log("  Deadline expired. Extended to: " + r.toString());
                });
            } else {
                console.log("  Deadline not expired. Deadline = " + r.toString());
            }
        });
    });

    it("Carol transfers funds to her exchange", () => {
        let fundsBefore, transferredAmount;
        let commission = web3.toWei(0.01, "ether");

        console.log("it: Carol transfers funds to her exchange");
        console.log("  Carol funds before = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));

        return instance.getAvailableFunds.call().then((r) => {
            fundsBefore = r.toNumber();
            console.log("  Contract funds before = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.getCommissionFunds.call();
        }).then((r) => {
            console.log("  Commission funds before = " + web3.fromWei(r,"ether").toString(10));
            console.log("  Alice adds commission funds");
            return instance.addCommissionFunds({from:alice, value:commission});
        }).then(() => {
            return instance.getCommissionFunds.call();
        }).then((r) => {
            console.log("  Commission funds after = " + web3.fromWei(r,"ether").toString(10));
            console.log("  Carol requests funds to be sent to her exchange...");
            return instance.sendFundsToExchange(password1, password2, commission, {from:carol});
        }).then(() => {
            return instance.getTransferredAmount.call();
        }).then((r) => {
            transferredAmount = r.toNumber();
            console.log("  Transferred Amount = " + web3.fromWei(r,"ether").toString(10));
            return instance.getAvailableFunds.call();
        }).then((r) => {
            console.log("  Contract funds after = " + web3.fromWei(r,"ether").toString(10));
            console.log("  Carol funds after = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));
            assert.equal(+fundsBefore, +r + +transferredAmount, "ERROR: Funds not transferred to Exchange");
        });
    });

    it("Carol transfer funds to Bob", () => {
        let bobFundsBefore, bobFundsAfter;
        let carolFundsBefore, carolFundsAfter; //Shall increase due to the commission
        let transferAmount = web3.toWei(0.1, "ether");

        console.log("it:Carol transfer funds to Bob");
        carolFundsBefore =  web3.fromWei(web3.eth.getBalance(carol),"ether");
        console.log("  Carol funds before = " + carolFundsBefore.toString(10));

        bobFundsBefore = web3.fromWei(web3.eth.getBalance(bob),"ether");
        console.log("  Bob funds before = " + bobFundsBefore.toFixed(5).toString(10));
        console.log("  Transfer amount = " + web3.fromWei(transferAmount,"ether").toString(10));

        return instance.getCommissionFunds.call().then((r) => {
            console.log("  Commission funds before = " + web3.fromWei(r,"ether").toString(10));
            console.log("  Carol sends funds to Bob and gets the commission paid...");
            return instance.sendFundsFromExchangeToBeneficiary({from:carol, value:transferAmount});
        }).then(() => {
            return instance.getCommissionFunds.call();
        }).then((r) => {
            console.log("  Commission funds after = " + web3.fromWei(r,"ether").toString(10));
            bobFundsAfter = web3.fromWei(web3.eth.getBalance(bob),"ether");
            console.log("  Bob funds after = " + bobFundsAfter.toFixed(5).toString(10));
            carolFundsAfter = web3.fromWei(web3.eth.getBalance(carol),"ether");
            console.log("  Carol funds after = " + carolFundsAfter.toString(10));

            assert.isAbove (+bobFundsAfter, +bobFundsBefore, "ERROR: Bob funds didn't increase");
            assert.isAbove (+carolFundsAfter + +transferAmount, +carolFundsBefore, "ERROR: Carol funds didn't receive the commission");
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
});
