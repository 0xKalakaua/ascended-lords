#!/usr/bin/python3
import os
from brownie import AscendedLords, accounts, network

def main():
    work = accounts.load("work")
    print(network.show_active())
    publish_source = True # Not supported on Testnet
    name = "Ascended Lords Test"
    symbol = "XFTL"
    base_uri = "https://fantomlordsapi.herokuapp.com/lords/"
    ftl = "0xAD66F519cA16aA2966dD581FF10155DE723b437F"
    artifacts = "0xd2F3A2d99EB2eE8D444d79442f7bc640A2656d34"
    max_supply = 122
    admin = "0x476e62b30E2587Ea937C19e2b60781e334fa29d7"
    AscendedLords.deploy(
                    name,
                    symbol,
                    base_uri,
                    ftl,
                    artifacts,
                    max_supply,
                    admin,
                    {"from": work},
                    publish_source=publish_source
    )
