pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";

contract Simple721 is ERC721Token {
    constructor() ERC721Token("Simple721", "S7") public { }
}
