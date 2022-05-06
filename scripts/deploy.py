#!/usr/bin/python3
import os
from brownie import AscendedLords, accounts, network

def main():
    work = accounts.load("work")
    print(network.show_active())
    publish_source = True # Not supported on Testnet
    name = "Ascended Lords"
    symbol = "XFTL"
    base_uri = "https://fantomlordsapi.herokuapp.com/lords/"
    ftl = "0xfee8077c909d956E9036c2d2999723931CeFE548"
    artifacts = "0xC021315E4aF3C6cbD2C96E5F7C67d0A4c2F8FE11"
    max_supply = 1222
    admin = "0x4a03721C829Ae3d448bF37Cac21527cbE75fc4Cb"
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
