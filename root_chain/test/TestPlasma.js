var PlasmaContract = artifacts.require("RootChain");
var Simple721Contract = artifacts.require("Simple721");

contract("PlasmaCashAuthorityContract", async (accounts) => {
  let instance;
  let s721Instance;

  let owner = accounts[0];

  before(async () => {
    s721Instance = await Simple721Contract.new({ from: owner });
    instance = await PlasmaContract.new(s721Instance.address, web3.toWei(0.05, "ether"), { from: owner });
  });

  describe("Contract information", async () => {
    it("owner is correct", async () => {
      assert.equal(await instance.authority(), owner);
    });
  });

  describe("Deposit", async () => {
    it("Run sample test", async () => {
      assert.equal(1, 1);
    });
  });
});
