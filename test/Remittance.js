var Remittance = artifacts.require("./Remittance.sol");

contract('Remittance', function(accounts) {
    var instance;

    var owner = accounts[0];
    var alice = accounts[1];
    var bob = accounts[2];
    var carol = accounts[3];

    var depositFunds = web3.toWei(4, "ether");
    var transferAmount = web3.toWei(2, "ether");

    var password1 = "123456";
    var password2 = "asd123";
    var hashKey;

    before (() => {
        return Remittance.new({from:owner}).then((i) => {
          instance = i;
        });
    });

    it("Alice deposits and withdraws funds", () => {
        let fundsBefore;
        let fundsAfter;

        console.log ("it: Alice deposits and withdraws funds");

        fundsBefore = web3.eth.getBalance(instance.address);
        console.log ("    Contract funds before = " + web3.fromWei(fundsBefore,"ether").toString(10));
        console.log ("    Alice deposits " + web3.fromWei(depositFunds, "ether") + " funds...");
        return instance.depositFunds({from:alice, value:depositFunds}).then(() => {
            fundsAfter = web3.eth.getBalance(instance.address);
            console.log ("    Contract funds after = " + web3.fromWei(fundsAfter, "ether").toString(10));
            assert.isBelow(+fundsBefore, +fundsAfter, "ERROR: funds after are not greater than funds before");
            fundsBefore = fundsAfter;
            console.log ("    Alice withdraws " + web3.fromWei(depositFunds/4) + " funds...")
            return instance.withdrawFunds(depositFunds/4, {from:alice});
        }).then(() => {
            fundsAfter = web3.eth.getBalance(instance.address);
            console.log ("    Contract funds after = " + web3.fromWei(fundsAfter, "ether").toString(10));
            assert.isAbove(+fundsBefore, +fundsAfter, "ERROR: Contract funds before are not greater than funds after");
        });
    });

    it("Alice registers a new Transfer to Bob via Carol's exchange", () => {
        console.log ("it: Alice registers a new Transfer to Bob via Carol's exchange");
        console.log ("    First Alice needs to obtain a hash key...");
        return instance.newTransferHashKey.call(password1, bob, password2).then((r) => {
            hashKey = r;
            console.log ("    Hash Key obtained: " + hashKey);
            console.log ("    Alice registers the Transfer...");
            return instance.newTransferWithExchange (hashKey, transferAmount, 100);
        }).then(() => {
            console.log ("    Transfer registered successfully");
            console.log ("    Getting Transfer details...");
            return instance.getTransferWithExchange.call(hashKey);
        }).then((r) => {
            console.log ("    Transfer amount = " + web3.fromWei(r[0].toString(), "ether"));
            console.log ("    Transfer deadline = " + r[1].toString());
            assert.equal (+transferAmount, +r[0], "    ERROR: Transfer infor is not correct");
        });
    });
    
    it("Carol withdraws Transfer amount by presenting the 2 paswords", () => {
        let fundsBefore;
        let fundsAfter;

        console.log ("it: Carol withdraws Transfer amount by presenting the 2 paswords");
        console.log ("    Carol funds before = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));
        fundsBefore = web3.eth.getBalance(instance.address);
        console.log ("    Contract funds before = " + web3.fromWei(fundsBefore,"ether").toString(10));
        console.log ("    Carol withdraws Transfer amount...");
        return instance.withdrawFromExchange(bob, password1, password2, {from:carol}).then(() => {
            fundsAfter = web3.eth.getBalance(instance.address);
            console.log ("    Contract funds before = " + web3.fromWei(fundsAfter,"ether").toString(10));
            console.log ("    Carol funds before = " + web3.fromWei(web3.eth.getBalance(carol),"ether").toString(10));
            assert.isBelow(+fundsAfter, +fundsBefore, "    ERROR: Funds not transferred to Exchange");
        });
    });

    it("Once the Transfer is done, Alice withdraws the remaining funds", () => {
        let aliceFundsBefore;
        let aliceFundsAfter;
        let contractFundsBefore;
        let contractFundsAfter;
        
        console.log ("it: Once the Transfer is done, Alice withdraws the remaining funds");
        
        aliceFundsBefore = web3.fromWei(web3.eth.getBalance(alice), "ether");
        console.log ("    Alice funds before = " + aliceFundsBefore.toString());
        contractFundsBefore = web3.fromWei(web3.eth.getBalance(instance.address), "ether");
        console.log ("    Contract funds before = " + contractFundsBefore);
        console.log ("    Alice withdraws remaining funds...");
        return instance.withdrawFunds(web3.toWei(contractFundsBefore), {from:alice}).then(() => {
            aliceFundsAfter = web3.fromWei(web3.eth.getBalance(alice), "ether");
            console.log ("    Alice funds before = " + aliceFundsAfter.toString());
            contractFundsAfter = web3.fromWei(web3.eth.getBalance(instance.address), "ether");
            console.log ("    Contract funds before = " + contractFundsAfter);
            assert.isAbove(+aliceFundsAfter, +aliceFundsBefore, "    ERROR: Funds not transfered to Alice successfully");
            assert.isBelow(+contractFundsAfter, +contractFundsBefore, "    ERROR: Funds not transfered to Alice successfully");
        })
    })
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
