pragma solidity ^0.4.23;

import './libraries/merkle.sol';
import './libraries/RLP.sol';
import './ERC721.sol';

contract RootChain {
    using Merkle for bytes32;
    using RLP for bytes;
    using RLP for RLP.RLPItem;
    using RLP for RLP.Iterator;

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
    mapping(uint => bytes32) public childChain; // store hash from child chain
    mapping(bytes32 => uint) public wallet; // store deposited tokenID
    mapping(bytes32 => address) public tokenOwner; // store owner of tokenID
    mapping(uint => uint) public exits; // store current exit requests

    /*
     * Modifiers
     */
    modifier isAuthority() {
        require(msg.sender == authority);
        _;
    }

    modifier isAccepted(address _address) {
        require(_address == tokenContract);
        _;
    }

    constructor(address _contract)
        public
    {
        authority = msg.sender;
        tokenContract = _contract;
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
    // @param currency The address of currency or zero if deposit Eth
    // @param amount The amount of currency to deposit
    function deposit(address tokenAddress, uint tokenID)
        public
        isAccepted(tokenAddress)
    {
        ERC721 token721 = ERC721(tokenAddress);
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
    {
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
    }
}
