pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC20Proxy.sol";
import "./ERC721Proxy.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

library VerifySignature {
    // Source: https://solidity-by-example.org/signature/

    function getMessageHash(NftMartketplace.Order memory _order) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _order.ERC721Address,
                _order.tokenID,
                _order.ERC20Address,
                _order.ERC20TokenAmount,
                _order.isSeller,
                _order.orderID
            )
        );
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32){
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function verify(address _signer, NftMartketplace.Order memory _order, bytes memory signature) public pure {
        bytes32 messageHash = getMessageHash(_order);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        require(recoverSigner(ethSignedMessageHash, signature) == _signer, 'incorrect signature');
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
contract NftMartketplace is ReentrancyGuard {
    struct OrderData{
        address ERC721Address;
        uint256 tokenID;
        address ERC20Address;
        uint256 ERC20TokenAmount;
        bool isSeller;
        uint256 orderID;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address ERC20Address,
        uint256 ERC20TokenAmount
    );
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address ERC20Address,
        uint256 price
    );

    mapping(uint256 => bool) public isOrderCompleted;
    ERC20TransferProxy public erc20TransferProxy;
    ERC721TransferProxy public erc721TransferProxy;
    uint256 public counter;

    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ){
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }


    function listItem(
            address nftAddress, address ERC20addr, 
            uint256 tokenId, uint256 price, bool isSeller
        )
            external
            isOwner(nftAddress, tokenId, msg.sender)
        {
            if (IERC20(ERC20addr).allowance(msg.sender, address(this)) == price) {
                revert PriceMustBeAboveZero();
            }
            IERC721 nft = IERC721(nftAddress);
            if (nft.getApproved(tokenId) != address(this)){
                revert NotApprovedForMarketplace();
            }
            //VerifySignature.getMessageHash(_order);
            emit ItemListed(msg.sender, nftAddress,ERC20addr,tokenId, price);
            return Order(nftAddress,ERC20addr,tokenId,price,isSeller);
        }

    function buyItem(
        address seller,OrderData memory sellOrder, bytes32 sellSig)
            external
            nonReentrant
        {
            VerifySignature.verify(seller, sellOrder, sellSig);
            erc721TransferProxy.erc721safeTransferFrom(listedItem.seller, msg.sender, tokenId);
            emit ItemBought(msg.sender, sellOrder.ERC721Address, sellOrder.tokenId,sellOrder.ERC20Address,sellOrder.ERC20TokenAmount);
        }

}