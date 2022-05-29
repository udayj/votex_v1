%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address, 
    get_block_timestamp
)

from starkware.cairo.common.math import (

    assert_lt,
    abs_value,
    assert_le
)

from starkware.cairo.common.math_cmp import is_le

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

@external
func vote{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt, current_vote:felt):


        assert_valid_id(id)
        let (current_proposal) = proposal.read(id)
        let (voter) = get_caller_address()
        let (prev_vote) = vote_history.read(id,voter)
        let (prev_vote_weightage) = vote_weightage_history.read(id,voter)
        
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

        # these multipliers are mutually exclusive i.e. only 1 of them will have value of 1
        tempvar yes_multiplier
        tempvar no_multiplier

        if current_vote==1:
            yes_multiplier=1
            no_multiplier=0
        else:
            yes_multiplier=0
            no_multiplier=1
        end
        
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

            # in the case that vote was changed, prev vote has to be subtracted and new vote added (with reduced weightage)
            # the following assertion checks that vote weightage will be atleast 1 after reduction
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
                            result=current_proposal.result
                            )
            proposal.write(id,new_proposal)
            vote_history.write(id,voter,current_vote)
            vote_weightage_history.write(id,voter,new_weightage)
            return()
        end

end

@external
func finalize_voting{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt):

    alloc_locals    
    assert_only_owner(id)
    assert_valid_id(id)
    let (local current_proposal) = proposal.read(id)
    let (local current_timestamp) = get_block_timestamp()
    with_attr error_message("Voting phase not over yet"):
            assert_lt(current_proposal.startTimestamp+current_proposal.duration,current_timestamp)
    end

    let yes_le_no:felt = is_le(current_proposal.count_yes, current_proposal.count_no)
    if yes_le_no==0:
        update_result(id,1)
        return()
    else:

        if current_proposal.count_yes == current_proposal.count_no:
            update_result(id,3)
            return()
        else:
            update_result(id,2)
            return()
        end
    end

    
end


@view
func get_result{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt) -> (res:felt):

    let (current_proposal) = proposal.read(id)
    let result = current_proposal.result

    return(result)
end

@view
func get_proposal{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt) -> (res:Proposal):

    
    let (current_proposal)=proposal.read(id)
    return (current_proposal)
end


@view
func get_proposal_id{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}() -> (res:felt):

    let (current_id) = proposal_id.read()
    return (current_id)
end

@view
func get_proposal_status{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt) -> (count_yes:felt, count_no:felt, result:felt):

    let (current_proposal)=proposal.read(id)

    let count_yes = current_proposal.count_yes
    let count_no = current_proposal.count_no
    let result = current_proposal.result

    return (count_yes, count_no, result)
end
    
@view
func testing_utility{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}() -> (timestamp:felt, res_neg:felt):

    let (current_timestamp)=get_block_timestamp()
    return (current_timestamp,-1)
end

func update_result{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt,result:felt):
    
    let (current_proposal) = proposal.read(id)
    let new_proposal:Proposal = Proposal(
                            id=current_proposal.id,
                            proposer=current_proposal.proposer,
                            startTimestamp=current_proposal.startTimestamp,
                            duration=current_proposal.duration,
                            metadata=current_proposal.metadata,
                            count_yes=current_proposal.count_yes,
                            count_no=current_proposal.count_no,
                            result=result
                            )
    proposal.write(id,new_proposal)
    return()
end

func assert_only_owner{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt):
    
    let (caller) = get_caller_address()
    let (current_proposal) = proposal.read(id)
    with_attr error_message("Not owner"):
        
        assert caller = current_proposal.proposer
    end
    return()
end

func assert_valid_id{syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(id:felt):

    let (current_id) = proposal_id.read()

    assert_le(id,current_id)
    return()
end







