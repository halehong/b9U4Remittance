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
        let fundsBefore, fundsAfter;

        console.log("it:Alice sends funds");

        return instance.viewFunds.call().then((r) => {
            fundsBefore = r;
                console.log("  fundsBefore = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.addFunds({from:alice, value:web3.toWei(0.2, "ether")});
        }).then(() => {
            return instance.viewFunds.call();
        }).then((r) => {
            fundsAfter = r;
                console.log("  fundsAfter = " + web3.fromWei(fundsAfter,"ether").toString(10));
            assert.isBelow(fundsBefore, fundsAfter, "ERROR: fundsAfter is not greater than fundsBefore");
        });
    });

    it("Alice withdraws funds", () => {
        let fundsBefore, fundsAfter;

        console.log("it:Alice withdraws funds");

        return instance.viewFunds.call().then((r) => {
            fundsBefore = r;
                console.log("  fundsBefore = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.withdrawFunds(web3.toWei(0.05, "ether"), {from:alice});
        }).then(() => {
            return instance.viewFunds.call();
        }).then((r) => {
            fundsAfter = r;
                console.log("  fundsAfter = " + web3.fromWei(fundsAfter,"ether").toString(10));
            assert.isAbove(fundsBefore, fundsAfter, "ERROR: fundsBefore is not greater than fundsAfter");
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
        let fundsBefore, fundsAfter;
        let transferAmount = web3.toWei(0.1, "ether");

        console.log("it: Carol transfers funds to her exchange");
        console.log("  Carol funds before = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));

        return instance.viewFunds.call().then((r) => {
            fundsBefore = r.toNumber();
                console.log("  Contract fundsBefore = " + web3.fromWei(fundsBefore,"ether").toString(10));
            return instance.fundsToExchange(password1, password2, transferAmount, {from:carol});
        }).then(() => {
                console.log("  transferAmount = " + web3.fromWei(transferAmount,"ether").toString(10));
            return instance.viewFunds.call();
        }).then((r) => {
            fundsAfter = r.toNumber();
                console.log("  Contract fundsAfter = " + web3.fromWei(fundsAfter,"ether").toString(10));
                console.log("  Carol funds after = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));
            assert.equal(+fundsBefore, +fundsAfter + +transferAmount, "ERROR: Funds not transfered to Exchange");
        });
    });

    it("Carol transfer funds to Bob", () => {
        let bobFundsBefore, bobFundsAfter;
        let transferAmount = web3.toWei(0.1, "ether") * 0.97; //Carol takes a 3% commission

        console.log("it:Carol transfer funds to Bob");
        console.log("  Carol funds before = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));

        bobFundsBefore = web3.fromWei(web3.eth.getBalance(bob),"ether");
            console.log("  Bob funds before = " + bobFundsBefore.toFixed(5).toString(10));
            console.log("  Transfer amount = " + web3.fromWei(transferAmount,"ether").toString(10));

        return instance.exchangeToBeneficiary({from:carol, value:transferAmount}).then(() => {
            bobFundsAfter = web3.fromWei(web3.eth.getBalance(bob),"ether");
                console.log("  Bob funds after = " + bobFundsAfter.toFixed(5).toString(10));
                console.log("  Carol funds after = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));

            let t = web3.fromWei(transferAmount,"ether");
            assert.equal ((+bobFundsBefore + +t).toFixed(5), (+bobFundsAfter).toFixed(5), "ERROR: Bob funds doesn't match");
        });
    });

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
});
