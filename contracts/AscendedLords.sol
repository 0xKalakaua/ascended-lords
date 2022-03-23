// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AscendedLords is AccessControl, ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public immutable MAX_SUPPLY;
    ERC721 public immutable fantomLords;
    ERC1155Burnable public immutable artifacts;

    Counters.Counter public _tokenIdCounter;

    Counters.Counter[9] private _classTokenIdCounters;
    string private _baseTokenURI;
    bool private _ascensionStarted = false;
    string private constant DEFAULT_LORE = "Ascended Lords are magical.";

    mapping(uint256 => string) private _lordNames;
    mapping(uint256 => string) private _lordLores;
    mapping(uint256 => string) private _lordClasses;
    mapping(uint256 => uint256) private _tokenIdToClassTokenId;

    constructor (
        string memory name,
        string memory symbol,
        string memory baseURI,
        ERC721 _fantomLords,
        ERC1155Burnable _artifacts,
        uint256 max,
        address admin)
        ERC721(name, symbol)
    {
        _tokenIdCounter.increment(); // Start collection at 1
        MAX_SUPPLY = max;
        _baseTokenURI = baseURI;
        fantomLords = _fantomLords;
        artifacts = _artifacts;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _;
    }

    function setBaseURI(string memory newBaseURI) external onlyAdmin {
        _baseTokenURI = newBaseURI;
    }
    
    function startAscension() external onlyAdmin {
        _ascensionStarted = true;
    }

    function lordName(uint256 tokenId) external view returns (string memory) {
        return _lordNames[tokenId];
    }

    function lordLore(uint256 tokenId) external view returns (string memory) {
        return _lordLores[tokenId];
    }

    function lordClass(uint256 tokenId) external view returns (string memory) {
        return _lordClasses[tokenId];
    }

    function classTokenId(uint256 tokenId) external view returns (uint256) {
        return _tokenIdToClassTokenId[tokenId];
    }

    function ascendLord(uint256 ftlTokenId, uint256 artifactTokenId) external {
        require(_ascensionStarted, "ascencion has not started yet");
        require(_tokenIdCounter.current() < MAX_SUPPLY, "all tokens have been minted");

        artifacts.burn(msg.sender, artifactTokenId, 1);
        fantomLords.safeTransferFrom(msg.sender, BURN_ADDRESS, ftlTokenId);
        _tokenIdCounter.increment();
        _classTokenIdCounters[artifactTokenId].increment();

        uint256 _tokenId = _tokenIdCounter.current();
        uint256 _classTokenId = _classTokenIdCounters[artifactTokenId].current();

        _tokenIdToClassTokenId[_tokenId] = _classTokenId;
        _lordNames[_tokenId] = string(abi.encodePacked("Ascended Lord #", _tokenId.toString()));
        _lordLores[_tokenId] = DEFAULT_LORE;
        _lordClasses[_tokenId] = _lordClassName(artifactTokenId);

        _safeMint(msg.sender, _tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _lordClassName(uint256 artifactTokenId) private pure returns (string memory) {
        if (artifactTokenId == 1) {
            return "CLASS 1";
        } else if (artifactTokenId == 2) {
            return "CLASS 2";
        } else if (artifactTokenId == 3) {
            return "CLASS 3";
        } else if (artifactTokenId == 4) {
            return "CLASS 4";
        } else if (artifactTokenId == 5) {
            return "CLASS 5";
        } else if (artifactTokenId == 6) {
            return "CLASS 6";
        } else if (artifactTokenId == 7) {
            return "CLASS 7";
        } else if (artifactTokenId == 8) {
            return "CLASS 8";
        } else {
            return "";
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
