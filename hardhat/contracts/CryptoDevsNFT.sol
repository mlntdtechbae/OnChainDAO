// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract CryptoDevsNFT is ERC721Enumerable {
    // initialize ERC-721 contract
    constructor() ERC721("CryptoDevs", "CD") {}

    // have public mint function that anyone can call to get an NFT
    function mint() public {
        _safeMint(msg.sender, totalSupply());
    }
}
