%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address, 
    get_block_timestamp
)

from starkware.cairo.common.math import (

    assert_lt,
    abs_value
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
#finalise vote
#get result
#get proposal
#get proposal status
#get proposal id
#get vote history

@external
func vote{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt, current_vote:felt):

        let (current_proposal) = proposal.read(id)
        let (voter) = get_caller_address()
        let (prev_vote) = vote_history.read(id,voter)
        let (prev_vote_weightage) = vote_weightage_history.read(id,voter)
        # if prev_vote = 0, prev_vote_weightage=10 write
        # if prev_vote ==current vote, return
        # if prev_vote !=current vote, update proposal
        # update vote_history, current weightage = prev wt -1, update wt history

        let (current_timestamp) = get_block_timestamp()

        with_attr error_message("Voting phase over"):
            assert_lt(current_timestamp,current_proposal.startTimestamp+current_proposal.duration)
        end

        if current_vote == 0:
            return()
        end

        if prev_vote == current_vote:
            return()
        end
        tempvar yes_multiplier = (current_vote + 1)/2
        tempvar no_multiplier:felt  = ((current_vote - 1)*(current_vote-1))/4
        if prev_vote == 0:

            let new_proposal:Proposal = Proposal(
                            id=current_proposal.id,
                            proposer=current_proposal.proposer,
                            startTimestamp=current_proposal.startTimestamp,
                            duration=current_proposal.duration,
                            metadata=current_proposal.metadata,
                            count_yes=current_proposal.count_yes+yes_multiplier*10,
                            count_no=current_proposal.count_no+no_multiplier*10,
                            result=0
                            )
            proposal.write(id,new_proposal)
            vote_history.write(id,voter,current_vote)
            vote_weightage_history.write(id,voter,10)
            return()
        else:
            assert_lt(1,prev_vote_weightage)
            let new_weightage=prev_vote_weightage-1
            let new_proposal:Proposal = Proposal(
                            id=current_proposal.id,
                            proposer=current_proposal.proposer,
                            startTimestamp=current_proposal.startTimestamp,
                            duration=current_proposal.duration,
                            metadata=current_proposal.metadata,
                            count_yes=current_proposal.count_yes+yes_multiplier*new_weightage-no_multiplier*prev_vote_weightage,
                            count_no=current_proposal.count_no+no_multiplier*new_weightage-yes_multiplier*prev_vote_weightage,
                            result=0
                            )
            proposal.write(id,new_proposal)
            vote_history.write(id,voter,current_vote)
            vote_weightage_history.write(id,voter,new_weightage)
            return()
        end

end



