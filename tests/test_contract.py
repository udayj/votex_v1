from ctypes import addressof
import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.business_logic.state.state import BlockInfo
from utils.Account import Account

# reference - https://perama-v.github.io/cairo/examples/test_accounts/
# Create signers that use a private key to sign transaction objects.
NUM_SIGNING_ACCOUNTS = 4
DUMMY_PRIVATE = 123456789987654321
# All accounts currently have the same L1 fallback address.
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def account_factory():
    # Initialize network
    starknet = await Starknet.empty()
    accounts = []
    print(f'Deploying {NUM_SIGNING_ACCOUNTS} accounts...')
    for i in range(NUM_SIGNING_ACCOUNTS):
        account = Account(DUMMY_PRIVATE + i, L1_ADDRESS)
        await account.create(starknet)
        accounts.append(account)
        print(f'Account {i} is: {account}')

    
    return starknet, accounts


@pytest.fixture(scope='module')
async def application_factory(account_factory):
    starknet, accounts = account_factory
    votemaster = await starknet.deploy(source="contracts/VoteMaster.cairo")

    return starknet, accounts, votemaster

@pytest.mark.asyncio
async def test_simple_vote(application_factory):

    starknet, accounts, votemaster = application_factory

    user_0=accounts[0]
    user_1=accounts[1]
    user_2=accounts[2]
    user_3=accounts[3]

    #print(starknet.state.state.block_info)

    await user_0.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='create_proposal',
        calldata=[300,0]
    )

    await user_0.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,1]

    )

    await user_1.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,1]

    )

    await user_2.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,2]

    )

    await user_3.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,2]

    )

    proposal_info=await votemaster.get_proposal(0).invoke()

    print(proposal_info.result)
    result = await votemaster.get_result(0).invoke()
    print(result.result)

    #print(starknet.state.state.block_info)

    await user_2.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,1]

    )

    proposal_info=await votemaster.get_proposal(0).invoke()

    print(proposal_info.result)
    assert proposal_info.result[0][5]==29
    assert proposal_info.result[0][6]==10
    await user_2.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='vote',
        calldata=[0,2]

    )
    proposal_info=await votemaster.get_proposal(0).invoke()
    print(proposal_info.result)
    assert proposal_info.result[0][5]==20
    assert proposal_info.result[0][6]==18
    assert proposal_info.result[0][7]==0

    starknet.state.state.block_info=BlockInfo(
        block_number=1, block_timestamp=500, gas_price=starknet.state.state.block_info.gas_price, 
        sequencer_address=starknet.state.state.block_info.sequencer_address
    )

    #print(starknet.state.state.block_info)

    await user_0.tx_with_nonce(
        to=votemaster.contract_address,
        selector_name='finalize_voting',
        calldata=[0]

    )
    proposal_info=await votemaster.get_proposal(0).invoke()
    print(proposal_info.result)
    assert proposal_info.result[0][5]==20
    assert proposal_info.result[0][6]==18
    assert proposal_info.result[0][7]==1
    