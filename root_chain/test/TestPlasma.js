var PlasmaContract = artifacts.require("RootChain");

contract("PlasmaCashAuthorityContract", async (accounts) => {
    let instance;

    let owner = accounts[0];

    before(async () => {
        // instance = await PlasmaContract.new({from: owner});
    });

    describe("Deposit", async () => {
        it("Run sample test", async () => {
            assert.equal(1, 1);
        });
    });
});
