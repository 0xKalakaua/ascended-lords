import pytest
import brownie
from brownie import accounts, chain, AscendedLords, Artifacts, ArcaneRelic, MockERC721
from brownie.test import given, strategy
import time

DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000"
LORE_SETTER_ROLE = "0x181e4536d3da760e63fbf18d0cd99792c7bd9f59e50a46e1780cae9d23b64205"
CLASSES = ["Exalted Champion", "Feral Stormcaller", "Hallowed Kensai",
           "Runebinder Magus", "Arcane Pathfinder", "Eldritch Dragonslayer",
           "Sanguine Sorcerer", "Glintstone Theurge", "Chosen One",
           "Burnt Offering"]

def print_lord_dist(asclords):
    tokens = [{}, {}, {}]
    class2id = {}

    for i in range(3):
        if "Chosen One" not in tokens[i]:
            tokens[i]["Chosen One"] = 0
        if "Burnt Offering" not in tokens[i]:
            tokens[i]["Burnt Offering"] = 0
        for j in range(asclords.balanceOf(accounts[i])):
            token_id = asclords.tokenOfOwnerByIndex(accounts[i], j)
            lord_class = asclords.lordClass(token_id)
            lord_class_id = asclords.lordClassId(token_id)
            class2id[lord_class] = lord_class_id
            try:
                tokens[i][lord_class] += 1
            except KeyError:
                tokens[i][lord_class] = 1

    for key in CLASSES:
        print(f"""{key}: {tokens[0][key]} + {tokens[1][key]} + {tokens[2][key]} \
= {asclords.totalSupplyPerClass(class2id[key])}""")

    total_1 = asclords.balanceOf(accounts[0])
    total_2 = asclords.balanceOf(accounts[1])
    total_3 = asclords.balanceOf(accounts[2])
    print(f"Total: {total_1} + {total_2} + {total_3} = {asclords.totalSupply()}")

def print_artifact_dist(artifacts):
    tokens = [{}, {}, {}]

    for i in range(3):
        for j in range(artifacts.balanceOf(accounts[i])):
            token_id = artifacts.tokenOfOwnerByIndex(accounts[i], j)
            try:
                tokens[i][artifacts.artifactType(token_id)] += 1
            except KeyError:
                tokens[i][artifacts.artifactType(token_id)] = 1

    for key in range(8):
        for i in range(3):
            if key not in tokens[i]:
                tokens[i][key] = 0
        print(f"""{key}: {tokens[0][key]} + {tokens[1][key]} + {tokens[2][key]} \
= {artifacts.totalSupplyPerType(key)}""")

    total_1 = artifacts.balanceOf(accounts[0])
    total_2 = artifacts.balanceOf(accounts[1])
    total_3 = artifacts.balanceOf(accounts[2])
    print(f"Total: {total_1} + {total_2} + {total_3} = {artifacts.totalSupply()}")

@pytest.fixture
def ftl():
    dev = accounts[0]
    max_supply = 120
    ftl = MockERC721.deploy("FTL Test", "FTL", max_supply, dev, {'from': dev})
    for i in range(1, max_supply + 1):
        ftl.mint(f"FTL #{i}", {'from': dev})
        if i > 40:
            if i <= 80:
                ftl.safeTransferFrom(dev, accounts[1], i, {'from': dev})
            else:
                ftl.safeTransferFrom(dev, accounts[2], i, {'from': dev})


    return ftl

@pytest.fixture
def artifacts():
    dev = accounts[0]
    xrlc = ArcaneRelic.deploy({'from': dev})

    name = "FTL Artifacts"
    symbol = "ARTIFACT"
    base_uri = "my_uri/"
    base_price = 122000000000000000000 # 122 * 1e18
    max_price = 222000000000000000000 # 222 * 1e18
    price_increase_factor = 827000000000000000 # 0.827
    max_supply = 120 
    admin = accounts[1]
    artifacts = Artifacts.deploy(
                                name,
                                symbol,
                                base_uri,
                                base_price,
                                max_price,
                                price_increase_factor,
                                max_supply,
                                xrlc,
                                admin,
                                {'from': dev})

    artifacts.startMint({'from': dev})
    for i in range(12):
        acc_nb = i % 3
        if i >= 8:
            acc_nb = 2
        elif i >= 4:
            acc_nb = 1
        else:
            acc_nb = 0
        xrlc.mint(accounts[acc_nb], "100000000 ether", {'from': dev})
        xrlc.approve(artifacts, "100000000 ether", {'from': accounts[acc_nb]})
        artifacts.collectArtifacts(10, {'from': accounts[acc_nb]})

    return artifacts

@pytest.fixture
def contracts(ftl, artifacts):
    dev = accounts[0]
    name = "Ascended Lords"
    symbol = "ASCLORD"
    base_uri = "my_uri/"
    max_supply = 120 
    admin = accounts[1]
    asclords = AscendedLords.deploy(
                                    name,
                                    symbol,
                                    base_uri,
                                    ftl,
                                    artifacts,
                                    max_supply,
                                    admin,
                                    {'from': dev})

    return ftl, artifacts, asclords

def test_initial_state(contracts):
    ftl, artifacts, asclords = contracts

    for i in range(3):
        assert ftl.balanceOf(accounts[i]) == 40
        assert artifacts.balanceOf(accounts[i]) == 40

    assert asclords.name() == "Ascended Lords"
    assert asclords.symbol() == "ASCLORD"

def test_uri(contracts):
    ftl, artifacts, asclords = contracts

    # not admin
    with brownie.reverts(f"""AccessControl: account \
{accounts[2].address.lower()} is missing role {DEFAULT_ADMIN_ROLE}"""):
        asclords.setBaseURI("new_uri/", {'from': accounts[2]})


    # URI query for nonexistent token
    with brownie.reverts("ERC721Metadata: URI query for nonexistent token"):
        asclords.tokenURI(1)

    ftl.setApprovalForAll(asclords, True, {'from': accounts[0]})
    artifacts.setApprovalForAll(asclords, True, {'from': accounts[0]})
    asclords.startAscension({'from': accounts[0]})
    asclords.ascendLord(1, 2, {'from': accounts[0]})

    assert asclords.tokenURI(1) == "my_uri/1"

    # test setURI
    asclords.setBaseURI("new_uri/", {'from': accounts[0]})
    assert asclords.tokenURI(1) == "new_uri/1"

def test_ascend_lord(contracts):
    ftl, artifacts, asclords = contracts

    # mint not started yet
    with brownie.reverts("ascension has not started yet"):
        asclords.ascendLord(1, 1, {'from': accounts[0]})

    # not admin
    with brownie.reverts(f"""AccessControl: account \
{accounts[2].address.lower()} is missing role {DEFAULT_ADMIN_ROLE}"""):
        asclords.startAscension({'from': accounts[2]})

    asclords.startAscension({'from': accounts[1]})

    # artifacts not approved
    with brownie.reverts("ERC721: transfer caller is not owner nor approved"):
        asclords.ascendLord(41, 50, {'from': accounts[1]})

    artifacts.setApprovalForAll(asclords, True, {'from': accounts[1]})

    # ftl not approved
    with brownie.reverts("ERC721: transfer caller is not owner nor approved"):
        asclords.ascendLord(41, 50, {'from': accounts[1]})

    ftl.setApprovalForAll(asclords, True, {'from': accounts[1]})

    # not owner of token
    with brownie.reverts("ERC721: transfer caller is not owner nor approved"):
        asclords.ascendLord(8, 51, {'from': accounts[1]})
        asclords.ascendLord(42, 1, {'from': accounts[1]})

    artifacts.setApprovalForAll(asclords, True, {'from': accounts[0]})
    ftl.setApprovalForAll(asclords, True, {'from': accounts[0]})
    artifacts.setApprovalForAll(asclords, True, {'from': accounts[2]})
    ftl.setApprovalForAll(asclords, True, {'from': accounts[2]})

    print_artifact_dist(artifacts)

    # normal mint
    for i in range(1, 121):
        if i == 120:
            # test team lord mint trying to mint more than what is left
            with brownie.reverts("not enough tokens left to mint"):
                asclords.teamUniqueLordMint(2, {'from': accounts[0]})
                asclords.teamCommonLordMint(2, 4, {'from': accounts[0]})

        if i > 40:
            if i <= 80:
                asclords.ascendLord(i, i, {'from': accounts[1]})
                assert asclords.lordName(i) == ""
            else:
                asclords.ascendLord(i, i, {'from': accounts[2]})
                assert asclords.lordLore(i) == ""
        else:
            asclords.ascendLord(i, i, {'from': accounts[0]})

    # test "all tokens have been minted"
    with brownie.reverts("all tokens have been minted"):
        asclords.ascendLord(1, 1, {'from': accounts[0]})
        # test team lord mint
        asclords.teamUniqueLordMint(3, {'from': accounts[1]})
        asclords.teamCommonLordMint(1, 2, {'from': accounts[1]})

    print_lord_dist(asclords)

    for i in range(3):
        assert ftl.balanceOf(accounts[i]) == 0
        assert artifacts.balanceOf(accounts[i]) == 0

    # dummy test to print stdout
    assert 1 == 2

def test_team_unique_lord_mint(contracts):
    ftl, artifacts, asclords = contracts

    # not admin
    with brownie.reverts(f"""AccessControl: account \
{accounts[3].address.lower()} is missing role {DEFAULT_ADMIN_ROLE}"""):
        asclords.teamUniqueLordMint(1, {'from': accounts[3]})

    # succesful mint
    asclords.teamUniqueLordMint(2, {'from': accounts[1]})
    assert asclords.lordName(1) == ""
    assert asclords.lordClass(1) == "Chosen One"
    assert asclords.lordClassId(1) == 8
    assert asclords.classTokenId(1) == 1
    assert asclords.totalSupplyPerClass(8) == 2

    # amount exceeds team allocation
    with brownie.reverts("amount exceeds team allocation"):
        asclords.teamUniqueLordMint(7, {'from': accounts[1]})

    # finish minting team allocation
    asclords.teamUniqueLordMint(6, {'from': accounts[0]})

    assert asclords.balanceOf(accounts[0]) == 6
    assert asclords.balanceOf(accounts[1]) == 2
    assert asclords.totalSupplyPerClass(8) == 8

def test_team_common_lord_mint(contracts):
    ftl, artifacts, asclords = contracts

    # not admin
    with brownie.reverts(f"""AccessControl: account \
{accounts[3].address.lower()} is missing role {DEFAULT_ADMIN_ROLE}"""):
        asclords.teamCommonLordMint(1, 2, {'from': accounts[3]})

    # lordClass not between 0-7
    with brownie.reverts("lordClass has to be between 0 and 7"):
        asclords.teamCommonLordMint(2, 8, {'from': accounts[0]})
        asclords.teamCommonLordMint(2, -1, {'from': accounts[0]})

    # succesful mint
    for i in range(1, 9):
        asclords.teamCommonLordMint(6, i-1, {'from': accounts[1]})
        assert asclords.lordName(i*6) == ""
        assert asclords.lordClass(i*6) == CLASSES[i-1]
        assert asclords.lordClassId(i*6) == i-1
        assert asclords.classTokenId(i*6) == 6

    for i in range(8):
        assert asclords.totalSupplyPerClass(i) == 6
    assert asclords.totalSupply() == 48

    # amount exceeds team allocation
    with brownie.reverts("amount exceeds team allocation"):
        asclords.teamCommonLordMint(3, 0, {'from': accounts[0]})

    # finish minting team allocation
    asclords.teamCommonLordMint(2, 0, {'from': accounts[0]})

    assert asclords.balanceOf(accounts[0]) == 2
    assert asclords.balanceOf(accounts[1]) == 48
    assert asclords.totalSupplyPerClass(0) == 8
    assert asclords.totalSupply() == 50

def test_change_lore(contracts):
    ftl, artifacts, asclords = contracts

    # not lore setter role
    with brownie.reverts(f"""AccessControl: account \
{accounts[2].address.lower()} is missing role {LORE_SETTER_ROLE}"""):
        asclords.changeLore(1, "new lore", {'from': accounts[2]})

    # nonexistent token
    with brownie.reverts("token does not exist"):
        asclords.changeLore(1, "new lore", {'from': accounts[0]})

    asclords.teamUniqueLordMint(2, {'from': accounts[1]})

    # succesful lore change
    asclords.changeLore(1, "new lore", {'from': accounts[0]})
    assert asclords.lordLore(1) == "new lore"

    # non admin lore change
    asclords.grantRole(LORE_SETTER_ROLE, accounts[2], {'from': accounts[1]})
    asclords.changeLore(2, "another lore", {'from': accounts[2]})
    assert asclords.lordLore(2) == "another lore"
