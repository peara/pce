const PlasmaContract = artifacts.require("RootChain");
const Simple721Contract = artifacts.require("Simple721");
const BN = web3.BigNumber;

import expectThrow from 'openzeppelin-solidity/test/helpers/expectThrow';
import expectEvent from 'openzeppelin-solidity/test/helpers/expectEvent';
import increaseTime from 'openzeppelin-solidity/test/helpers/increaseTime';
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
      assert.equal((await instance.depositPeriod()).toNumber(), 600, 'Deposit Period is incorrect');
      assert.equal((await instance.exitPeriod()).toNumber(), 604800, 'Exit Period is incorrect');
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
      await expectThrow(instance.deposit(2, { from: user2 }));
    });

    it("Cannot deposit other token", async () => {
      await expectThrow(instance.deposit(2, { from: user1 }));
    });

    it("can deposit approved token", async () => {
      let event = await expectEvent.inTransaction(
        instance.deposit(1, { from: user1 }),
        'Deposit'
      );
      assert.equal(await s721Instance.ownerOf(1), instance.address, 'Owner is not Plasma contract');
      let uid = event.args.uid;
      let blockTime = web3.eth.getBlock(event.blockNumber).timestamp;

      assert.deepEqual(await instance.wallet(uid), new BN(1), 'Deposit token ID is incorrect');
      assert.equal(await instance.tokenOwner(uid), user1, 'Depositor is incorrect');
      assert.deepEqual(await instance.depositCount(), new BN(1), 'Deposit count is incorrect');
      assert.equal((await instance.waitingDeposit(uid)).toNumber(), blockTime + 600, 'Cancel deadline is incorrect');
    });

    describe("can cancel deposit request", async () => {
      before(async () => {
        await s721Instance.mint(user1, 3, { from: owner });
      });

      it("can cancel deposit request", async () => {
        await s721Instance.approve(instance.address, 3, { from: user1 });
        let event = await expectEvent.inTransaction(
          instance.deposit(3, { from: user1 }),
          'Deposit'
        );
        let uid = event.args.uid;
        await instance.cancelDeposit(uid, { from: user1 });

        assert.equal(await s721Instance.ownerOf(3), user1, 'Owner is not user');
        assert.equal(await instance.wallet(uid), 0);
        assert.equal(await instance.tokenOwner(uid), 0);
      });

      it("cannot cancel after depositPeriod", async () => {
        await s721Instance.approve(instance.address, 3, { from: user1 });
        let event = await expectEvent.inTransaction(
          instance.deposit(3, { from: user1 }),
          'Deposit'
        );
        let uid = event.args.uid;
        let cancelDeadline = (await instance.waitingDeposit(uid)).toNumber();

        await increaseTime(601);
        console.log('Cancel time:  ', cancelDeadline);
        console.log('Current time: ', web3.eth.getBlock('latest').timestamp);
        assert.equal(web3.eth.getBlock('latest').timestamp > cancelDeadline, true, 'DepositPeriod not passed');
        await expectThrow(instance.cancelDeposit(uid, { from: user1 }));
      });
    });
  });

  describe("Submit Block", async () => {

  });

  describe("Exit and Challenge", async () => {
    before(async () => {
        console.log(await instance.depositCount());
    });

    it("Sample test", async () => {
        assert.equal(1, 1);
    });
  });
});
