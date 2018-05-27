const PlasmaContract = artifacts.require("RootChain");
const Simple721Contract = artifacts.require("Simple721");
const BN = web3.BigNumber;

import expectThrow from 'openzeppelin-solidity/test/helpers/expectThrow';
import expectEvent from 'openzeppelin-solidity/test/helpers/expectEvent';
import BN2B32 from './helpers/BigNumberToBytes32.js';

contract("PlasmaCashAuthorityContract", async (accounts) => {
  let instance;
  let s721Instance;

  let owner = accounts[0];
  let user1 = accounts[1];
  let user2 = accounts[2];

  before(async () => {
    s721Instance = await Simple721Contract.new({ from: owner });
    instance = await PlasmaContract.new(s721Instance.address, web3.toWei(0.05, "ether"), { from: owner });
  });

  describe("Contract information", async () => {
    it("owner is correct", async () => {
      assert.equal(await instance.authority(), owner);
    });

    it("token contract is correct", async () => {
      assert.equal(await instance.tokenContract(), s721Instance.address);
    });
  });

  describe("Deposit", async () => {
    before(async () => {
      await s721Instance.mint(user1, 1, { from: owner });
      await s721Instance.mint(user2, 2, { from: owner });
      await s721Instance.approve(instance.address, 1, { from: user1 });
    });

    it("Cannot deposit if not approved", async () => {
      expectThrow(instance.deposit(2, { from: user2 }));
    });

    it("Cannot deposit other token", async () => {
      expectThrow(instance.deposit(2, { from: user1 }));
    });

    it("can deposit approved token", async () => {
      let event = await expectEvent.inTransaction(
        instance.deposit(1, { from: user1 }),
        'Deposit'
      );
      assert.equal(await s721Instance.ownerOf(1), instance.address);

      let uid = BN2B32(event.args.uid);
      assert.deepEqual(await instance.wallet(uid), new BN(1));
      assert.equal(await instance.tokenOwner(uid), user1);
      assert.deepEqual(await instance.depositCount(), new BN(1));
    });
  });
});
