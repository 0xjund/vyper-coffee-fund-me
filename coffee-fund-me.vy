# pragma version 0.4.0
"""
@license MIT
@title Buy Me a Coffee
@author 0xJund
@notice This contract is about creating a sample funding contract. Users can deposit ETH and the only the owner can withdraw the ETH deposited by funders
"""

interface AggregatorV3Interface:
    def decimals() -> uint8: view
    def description() -> String[1000]: view
    def version() -> uint256: view
    def latestAnswer() -> int256: view

# Constants and Immutables
MINIMUM_USD_VALUE: public(constant(uint256)) = as_wei_value(5, "ether")
PRICE_FEED: public(immutable(AggregatorV3Interface)) #Sepolia:0x694AA1769357215DE4FAC081bf1f309aDC325306
OWNER: public(immutable(address))
PRECISION: constant(uint256) = 1 * (10 ** 18)

# Storage Variables
funders: public(DynArray[address, 1000])
# funder to amount funded
funder_to_amount_funded: public(HashMap[address, uint256])

@deploy
def __init__(price_feed_address: address):
    PRICE_FEED = AggregatorV3Interface(price_feed_address)
    OWNER = msg.sender

@external
def fund():
    self._fund()


@internal
@payable
def _fund():
    """ Allows user to fund the contract with ETH. Needs a minimum amount to be funded
    """
    usd_value_of_eth: uint256 = self._get_eth_to_usd_rate(msg.value)
    assert msg.value >= MINIMUM_USD_VALUE, "You must spend more ETH"
    self.funders.append(msg.sender)
    self.funder_to_amount_funded[msg.sender] += msg.value

@external
def withdraw():
    """ Take the money out that people sent via the send function
    """
    assert msg.sender == OWNER, "Not the contract owner!"
    raw_call(OWNER, b"", value = self.balance)
    # Vyper has a built in revert on fail
    # send(OWNER, self.balance) --> don't use this!
    # self.balance refers to the balance of the contract
    # Resets the array after withdrawal
    for funder: address in self.funders:
        self.funder_to_amount_funded[funder] = 0

    self.funders = []

@internal
@view
def _get_eth_to_usd_rate(eth_amount: uint256) -> uint256:
    price: int256 = staticcall PRICE_FEED.latestAnswer()
    # Change to 18 decimals
    # Can convert types in vyper
    eth_price: uint256 = (convert(price, uint256)) *(10 ** 10)
    eth_amount_in_usd: uint256 = eth_amount * eth_price // PRECISION
    return eth_amount_in_usd

@external
@view
def get_eth_to_usd_rate(eth_amount: uint256) -> uint256 :
    return self._get_eth_to_usd_rate(eth_amount)

@external
@payable
def __default__():
    self._fund()

# @external
# @view
# def get_price() -> int256:
#     price_feed: AggregatorV3Interface = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306)
#     return staticcall price_feed.latestAnswer()
