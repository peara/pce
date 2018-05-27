pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";

contract Simple721 is ERC721Token {
    constructor() ERC721Token("Simple721", "S7") public { }

    function mint(address _to, uint _tokenID) public {
        super._mint(_to, _tokenID);
    }


    function burn(uint256 _tokenId) public {
        super._burn(ownerOf(_tokenId), _tokenId);
    }
}
