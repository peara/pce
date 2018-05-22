pragma solidity ^0.4.23;

import './libraries/merkle.sol';
import './libraries/RLP.sol';
import './ERC721.sol';

// TODO: missing operator bond (in ETH) and reward (in some token, or ETH if we have some fees)
contract RootChain {
    using Merkle for bytes32;
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLP for RLP.Iterator;

    struct ExitInfo {
        address requester;
        uint prevTxBlkNum;
        address prevTxRec;
        uint curTxBlkNum;
        address curTxRec;
        uint bond;
    }

    /*
     * Events
     */
    event Deposit(address depositor, uint256 tokenID, uint256 uid);

    /*
     * Storage
     */
    address public authority;
    address public tokenContract; // only accept token from this contract
    uint public depositCount;
    uint public currentBlkNum;
    uint public minimumBond;
    mapping(uint => bytes32) public childChain; // store hash from child chain
    mapping(bytes32 => uint) public wallet; // store deposited tokenID, this contract token ID => ERC721 token ID
    mapping(bytes32 => address) public tokenOwner; // store owner of tokenID, for checkpointing and client validation
    mapping(uint => uint) public exits; // store current exit requests
    mapping(uint => ExitInfo) public exitInfos;

    /*
     * Modifiers
     */
    modifier isAuthority() {
        require(msg.sender == authority);
        _;
    }

    modifier exitRequestExisted(uint uid) {
        require(exits[uid] != 0);
        require(block.timestamp < exits[uid]);
        _;
    }

    constructor(address _contract, uint _minimumBond)
        public
    {
        authority = msg.sender;
        tokenContract = _contract;
        minimumBond = _minimumBond;
        depositCount = 0;
        currentBlkNum = 0;
    }

    // @dev Allows Plasma chain operator to submit block root
    // @param blkRoot The root of a child chain block (only contain transaction of )
    // @param blknum The child chain block number
    function submitBlock(bytes32 blkRoot, uint blknum)
        public
        isAuthority
    {
        require(currentBlkNum + 1 == blknum);
        childChain[blknum] = blkRoot;
        currentBlkNum += 1;
    }

    // @dev Allows anyone to deposit funds into the Plasma chain
    // @param amount The amount of currency to deposit
    function deposit(uint tokenID)
        public
    {
        ERC721 token721 = ERC721(tokenContract);
        require(token721.ownerOf(tokenID) == msg.sender); // only owner of token can deposit

        // expect to be approved first
        token721.transferFrom(msg.sender, address(this), tokenID);

        // why not use an array?
        // it seems that this is easier to manage (delete) than using an array
        // the collision rate should be very very low anyway
        // so we can ignore the case uid is already taken for now
        bytes32 uid = keccak256(msg.sender, tokenID, depositCount);
        wallet[uid] = tokenID;
        tokenOwner[uid] = msg.sender;

        depositCount += 1;
        emit Deposit(msg.sender, tokenID, uint256(uid));
    }

    function normalExit(
        bytes prevTx,
        bytes prevTxProof,
        uint prevTxBlkNum,
        bytes curTx,
        bytes curTxProof,
        uint curTxBlkNum
    )
        public
        payable
    {
        require(msg.value >= minimumBond);

        RLP.RLPItem[] memory prevTxList = prevTx.toRLPItem().toList();
        RLP.RLPItem[] memory txList = curTx.toRLPItem().toList();
        require(prevTxList.length == 4);
        require(txList.length == 4);

        // tx's format:
        // 0: prev blocknumber
        // 1: uid
        // 2: receiver
        // 3: signature

        require(prevTxBlkNum == txList[0].toUint());
        require(prevTxList[1].toUint() == txList[1].toUint());
        require(msg.sender == txList[3].toAddress()); // tx_to = msg.sender
        // TODO: check signature - signer of tx = receiver of prevTx

        uint uid = txList[1].toUint();

        bytes32 prevMerkleHash = keccak256(prevTx);
        bytes32 prevRoot = childChain[prevTxBlkNum];
        bytes32 merkleHash = keccak256(curTx);
        bytes32 root = childChain[curTxBlkNum];
        require(prevMerkleHash.checkMembership(uid, prevRoot, prevTxProof));
        require(merkleHash.checkMembership(uid, root, curTxProof));

        // Record the exitable timestamp.
        require(exits[uid] == 0);
        exits[uid] = block.timestamp + 2 weeks;

        // TODO: store exit information
        // exitInfos[uid] = ExitInfo();
    }

    // Allow anyone to finalize an exit which has passed challenge phase
    function finalizeExit(uint uid) public {
        require(exits[uid] != 0);
        require(block.timestamp >= exits[uid]);

        ExitInfo storage info = exitInfos[uid];
        ERC721 token721 = ERC721(tokenContract);

        bytes32 wuid = uintToBytes(uid);
        token721.transfer(info.curTxRec, wallet[wuid]); // transfer the token
        info.curTxRec.transfer(info.bond); // return the bond

        // remove token info
        delete wallet[wuid];
        delete tokenOwner[wuid];

        // remove exit request
        delete exits[uid];
        delete exitInfos[uid];
    }

    // This challenge presents a transaction spend the last tx
    // will invalidate the exit request instantly if correct
    function challengeType1(
        uint uid,
        bytes chaTx,
        bytes chaTxProof,
        uint chaTxBlkNum
    )
        public
        exitRequestExisted(uid)
    {
        RLP.RLPItem[] memory chaTxList = chaTx.toRLPItem().toList();
        require(chaTxList.length == 4);

        ExitInfo storage info = exitInfos[uid];
        require(chaTxList[0].toUint() == info.curTxBlkNum); // prev block is curTx
        require(chaTxList[1].toUint() == uid); // same uid
        // TODO: check signature of chaTx is info.curTxRec

        bytes32 merkleHash = keccak256(chaTx);
        bytes32 root = childChain[chaTxBlkNum];
        require(merkleHash.checkMembership(uid, root, chaTxProof)); // valid proof

        _invalidateExit(msg.sender, uid);
    }

    // This challenge presents a transaction spend prevTx and before curTx
    // will invalidate the exit request instantly if correct
    function challengeType2(
        uint uid,
        bytes chaTx,
        bytes chaTxProof,
        uint chaTxBlkNum
    )
        public
        exitRequestExisted(uid)
    {
        RLP.RLPItem[] memory chaTxList = chaTx.toRLPItem().toList();
        require(chaTxList.length == 4);

        ExitInfo storage info = exitInfos[uid];
        require(chaTxList[0].toUint() == info.prevTxBlkNum); // prev block is prevTx
        require(chaTxList[1].toUint() == uid); // same uid
        require(chaTxBlkNum < info.curTxBlkNum); // before last tx
        // TODO: check signature of chaTx is info.prevTxRec

        bytes32 merkleHash = keccak256(chaTx);
        bytes32 root = childChain[chaTxBlkNum];
        require(merkleHash.checkMembership(uid, root, chaTxProof)); // valid proof

        _invalidateExit(msg.sender, uid);
    }

    function _invalidateExit(address challenger, uint uid) internal {
        challenger.transfer(exitInfos[uid].bond); // send bond to challenger
        delete exits[uid];
        delete exitInfos[uid];
    }

    // TODO: refactor to a lib
    function uintToBytes(uint256 x) public pure returns (bytes32 b) {
        assembly { mstore(add(b, 32), x) }
    }
}
