%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address, 
    get_block_timestamp
)
struct Proposal:

    member id: felt
    member proposer: felt
    member startTimestamp:felt
    member duration:felt
    member metadata:felt
    member count_yes:felt
    member count_no:felt
    member result:felt
end


@storage_var
func proposal(id: felt) -> (res : Proposal):
end

@storage_var
func proposal_id() -> (res: felt):
end

@storage_var
func vote_history(id:felt, voter:felt) ->(prev_vote_type:felt):
end

@storage_var
func vote_weightage_history(id:felt, voter:felt) -> (prev_vote_weightage:felt):
end

@external
func create_proposal{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(duration:felt, metadata:felt):

    let (current_proposal_id)=proposal_id.read()

    let (proposer) = get_caller_address()
    let (startTimestamp) = get_block_timestamp()

    let new_proposal:Proposal = Proposal(
                            id=current_proposal_id,
                            proposer=proposer,
                            startTimestamp=startTimestamp,
                            duration=duration,
                            metadata=metadata,
                            count_yes=0,
                            count_no=0,
                            result=0
                            )

    proposal.write(current_proposal_id,new_proposal)
    proposal_id.write(current_proposal_id+1)
    return()
end

#vote
#get result
#get proposal
#get proposal status
#get proposal id
#get vote history




