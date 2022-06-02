pragma solidity ^0.8.1;  

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {
    constructor(uint256 tokenID) ERC721("TestToken721","721TTK"){
        _safeMint(msg.sender, tokenID);
    }
}