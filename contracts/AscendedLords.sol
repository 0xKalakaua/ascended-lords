// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface ArtifactsInterface {
    function artifactType(uint256 tokenId) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

}

contract AscendedLords is AccessControl, ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant LORE_SETTER_ROLE = keccak256("LORE_SETTER_ROLE");
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public immutable MAX_SUPPLY;
    ERC721 public immutable fantomLords;
    ArtifactsInterface public immutable artifacts;

    Counters.Counter public _tokenIdCounter;

    Counters.Counter[10] private _classTokenIdCounters;
    Counters.Counter private teamUniqueLordCounter;
    Counters.Counter private teamCommonLordCounter;
    uint256 private constant TEAM_COMMON_LORD_ALLOCATION = 50;
    uint256 private constant TEAM_UNIQUE_LORD_ALLOCATION = 8;
    uint256 private constant MAX_LORDS_PER_CLASS = 300;
    uint256 private constant MAX_UNIQUE_LORDS = 30;
    uint256 private constant MAX_BURNED_LORDS = 10;
    uint256 private constant UNIQUE_LORDS_PROB = 30; // 3% probability
    uint256 private constant BURNED_LORDS_PROB = 17; // 1.7% probability
    uint256 private _nonce;
    string private _baseTokenURI;
    bool private _ascensionStarted = false;

    mapping(uint256 => string) private _lordNames;
    mapping(uint256 => string) private _lordLores;
    mapping(uint256 => string) private _lordClasses;
    mapping(uint256 => uint256) private _lordClassIds;
    mapping(uint256 => uint256) private _tokenIdToClassTokenId;

    constructor (
        string memory name,
        string memory symbol,
        string memory baseURI,
        ERC721 _fantomLords,
        ArtifactsInterface _artifacts,
        uint256 maxSupply,
        address admin)
        ERC721(name, symbol)
    {
        MAX_SUPPLY = maxSupply;
        _baseTokenURI = baseURI;
        fantomLords = _fantomLords;
        artifacts = _artifacts;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LORE_SETTER_ROLE, admin);
        _setupRole(LORE_SETTER_ROLE, msg.sender);
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

    function lordClassId(uint256 tokenId) external view returns (uint256) {
        return _lordClassIds[tokenId];
    }

    function classTokenId(uint256 tokenId) external view returns (uint256) {
        return _tokenIdToClassTokenId[tokenId];
    }


    function ascendLord(uint256 ftlTokenId, uint256 artifactTokenId) external {
        uint256 artifactType = artifacts.artifactType(artifactTokenId);

        require(_ascensionStarted, "ascension has not started yet");
        require(_tokenIdCounter.current() < MAX_SUPPLY, "all tokens have been minted");
        require(
            totalSupplyPerClass(artifactType) < MAX_LORDS_PER_CLASS,
            "all lords of that class have been ascended"
        );

        artifactType = _uniqueOrBurnedLord(artifactType);

        artifacts.safeTransferFrom(msg.sender, BURN_ADDRESS, artifactTokenId);
        fantomLords.safeTransferFrom(msg.sender, BURN_ADDRESS, ftlTokenId);
        _tokenIdCounter.increment();
        _classTokenIdCounters[artifactType].increment();

        uint256 _tokenId = _tokenIdCounter.current();
        uint256 _classTokenId = _classTokenIdCounters[artifactType].current();

        _tokenIdToClassTokenId[_tokenId] = _classTokenId;
        _lordClasses[_tokenId] = _lordClassName(artifactType);
        _lordClassIds[_tokenId] = artifactType;

        _safeMint(msg.sender, _tokenId);
    }

    function teamUniqueLordMint(uint256 amount) external onlyAdmin {
        require(
            teamUniqueLordCounter.current() + amount <= TEAM_UNIQUE_LORD_ALLOCATION,
            "amount exceeds team allocation"
        );
        require(_tokenIdCounter.current() < MAX_SUPPLY, "all tokens have been minted");
        require(
            _tokenIdCounter.current() + amount < MAX_SUPPLY + 1,
            "not enough tokens left to mint"
        );
        require(totalSupplyPerClass(8) < MAX_UNIQUE_LORDS, "all unique lords have been minted");

        uint256 lordClass = 8;
        for (uint256 i = 0; i < amount; ++i) {

            _tokenIdCounter.increment();
            _classTokenIdCounters[lordClass].increment();

            uint256 _tokenId = _tokenIdCounter.current();
            uint256 _classTokenId = _classTokenIdCounters[lordClass].current();

            _tokenIdToClassTokenId[_tokenId] = _classTokenId;
            _lordClasses[_tokenId] = _lordClassName(lordClass);
            _lordClassIds[_tokenId] = lordClass;

            teamUniqueLordCounter.increment();
            _safeMint(msg.sender, _tokenId);
        }
    }

    function teamCommonLordMint(uint256 amount, uint256 lordClass) external onlyAdmin {
        require(lordClass <= 7, "lordClass has to be between 0 and 7");
        require(
            teamCommonLordCounter.current() + amount <= TEAM_COMMON_LORD_ALLOCATION,
            "amount exceeds team allocation"
        );
        require(_tokenIdCounter.current() < MAX_SUPPLY, "all tokens have been minted");
        require(
            _tokenIdCounter.current() + amount < MAX_SUPPLY + 1,
            "not enough tokens left to mint"
        );
        require(
            totalSupplyPerClass(lordClass) + amount < MAX_LORDS_PER_CLASS + 1,
            "all lords of that class have been ascended"
        );

        for (uint256 i = 0; i < amount; ++i) {

            _tokenIdCounter.increment();
            _classTokenIdCounters[lordClass].increment();

            uint256 _tokenId = _tokenIdCounter.current();
            uint256 _classTokenId = _classTokenIdCounters[lordClass].current();

            _tokenIdToClassTokenId[_tokenId] = _classTokenId;
            _lordClasses[_tokenId] = _lordClassName(lordClass);
            _lordClassIds[_tokenId] = lordClass;

            teamCommonLordCounter.increment();
            _safeMint(msg.sender, _tokenId);
        }
    }

    function changeLore(uint256 tokenId, string memory newLore)
        external
        onlyRole(LORE_SETTER_ROLE)
    {
        require(_exists(tokenId), "token does not exist");
        _lordLores[tokenId] = newLore;
    }

    function changeName(uint256 tokenId, string memory newName)
        external
        onlyRole(LORE_SETTER_ROLE)
    {
        require(_exists(tokenId), "token does not exist");
        _lordNames[tokenId] = newName;
    }

    function totalSupplyPerClass(uint256 lordClassId) public view returns (uint256) {
        return _classTokenIdCounters[lordClassId].current();
    }


    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _uniqueOrBurnedLord(uint256 artifactType) private returns (uint256) {
        uint256 randomNb = 
            uint256(keccak256(abi.encodePacked(++_nonce, block.timestamp, msg.sender, blockhash(block.number - 1)))) % 1000;

        if (randomNb < (UNIQUE_LORDS_PROB + BURNED_LORDS_PROB)) {
            if (totalSupplyPerClass(8) < MAX_UNIQUE_LORDS) {
                artifactType = 8;
            }
            if (randomNb < BURNED_LORDS_PROB &&
                totalSupplyPerClass(9) < MAX_BURNED_LORDS) {
                artifactType = 9;
            }
        }
        return artifactType;
    }

    function _lordClassName(uint256 artifactType) private pure returns (string memory) {
        if (artifactType == 0) {
            return "Exalted Champion";
        } else if (artifactType == 1) {
            return "Feral Stormcaller";
        } else if (artifactType == 2) {
            return "Hallowed Kensai";
        } else if (artifactType == 3) {
            return "Runebinder Magus";
        } else if (artifactType == 4) {
            return "Arcane Pathfinder";
        } else if (artifactType == 5) {
            return "Eldritch Dragonslayer";
        } else if (artifactType == 6) {
            return "Sanguine Sorcerer";
        } else if (artifactType == 7) {
            return "Glintstone Theurge";
        } else if (artifactType == 8) {
            return "Chosen One";
        } else if (artifactType == 9) {
            return "Burnt Offering";
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
