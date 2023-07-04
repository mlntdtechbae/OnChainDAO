// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// interface for the FakeNFTMarketplace
interface IFakeNFTMarketplace {
    // getPrice() returns price of NFT from the FakeNFTMP
    // returns price in wei for NFT
    function getPrice() external view returns (uint256);

    // available() returns whether or not the given _tokenId has been purchased
    // returns bool value - true = available, false = not available
    function available(uint256 _tokenId) external view returns (bool);

    // purchase() purchases NFT from FakeNFTMP
    // _tokenId - fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

// minimal interface for CryptoDevsNFT containing only 2 functions that we are interested in
interface ICryptoDevsNFT {
    // balanceOf returns number of NFTs owned by given address
    // owner - address to fetch number of NFTs for
    // returns number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    // tokenOfOwnerByIndex returns a tokenID at given index for owner
    // owner - address to fetch NFT TokenID for
    // index - index of NFT in owned tokens array to fetch
    // returns TokenID of the NFT
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}

// contract address: 0x44f233365740a8aeB1ffAD9AB854526B2984D1De
contract CryptoDevsDAO is Ownable {
    // create struct named Proposal containing all relevant info
    struct Proposal {
        // nftTokenId - the tokenID of the NFT to purchase from FakeNFTMarketplace if the proposal passes
        uint256 nftTokenId;
        // deadline - the UNIX timestamp until this proposal is active
        // proposal can be executed after deadline has been exceeded
        uint256 deadline;
        // yayVotes - num of yay votes
        uint256 yayVotes;
        // nayVotes - num of nay votes
        uint256 nayVotes;
        // executed - whether or not proposal has been executed yet
        // cannot be executed before deadline has been exceeded
        bool executed;
        // voters - mapping of CryptoDevsNFT tokenIDs to bool, indicating whether NFT has already been used to cast vote or not
        mapping(uint256 => bool) voters;
    }

    // create mapping of ID to Proposal
    mapping(uint256 => Proposal) public proposals;
    // number of proposals that have been created
    uint256 public numProposals;

    // variables to store contracts
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    // create payable constructor to initializes the contract
    // instances for FakeNFTMP & CryptoDevsNFT
    // payable allows constructor to accept ETH deposit when it is being deployed
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    // create modifier that only allows function to be called by someone who owns at least 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    // createProposal allows CryptoDevsNFT holder to create new proposal in DAO
    // _nftTokenId - the tokenID of NFT to be purchased from FakeNFTMP, if proposal passes
    // returns proposal index for newly created proposal
    function createProposal(
        uint256 _nftTokenId
    ) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        // Set the proposal's voting deadline to be (current time + 5 minutes)
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        return numProposals - 1;
    }

    // create modifier that only allows function to be called if the given proposal's deadline has not been exceeded yet
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    // create enum named 'Vote' containing possible options for vote
    enum Vote {
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    // voteOnProposal allows CryptoDevsNFT holder to cast vote on active proposals
    // proposalIndex - the index of proposal to vote on, in the proposals array
    // vote - type of vote they want to cast
    function voteOnProposal(
        uint256 proposalIndex,
        Vote vote
    ) external nftHolderOnly activeProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        // calculate how many NFTs are owned by voter that haven't already been used for voting on this proposal
        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    // create a modifier that only allows function to be called if the given proposals' deadline HAS been exceeded
    // and if proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "DEADLINE_NOT_EXCEEDED"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    // executeProposal allows any CryptoDevsNFT holder to execute proposals after it's deadline has been exceeded
    // proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(
        uint256 proposalIndex
    ) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        // if the proposal has more YAY votes than NAY votes
        // purchase the NFT from the FakeNFTMarketplace
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    // withdrawEther allows contract owner (deployer) to withdraw ETH from contract
    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw, contract balance empty");
        (bool sent, ) = payable(owner()).call{value: amount}("");
        require(sent, "FAILED_TO_WITHDRAW_ETHER");
    }

    // following two functions allow contract to accept ETH deposits directly from a wallet without, calling function
    receive() external payable {}

    fallback() external payable {}
}
