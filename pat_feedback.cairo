%lang starknet

@storage_var
func feedback_length(token_id: felt) -> (len: felt):
end

@storage_var
func feedback_char(token_id: felt, index: felt) -> (char: felt):
end

@event
func FeedbackSubmitted(token_id: felt, feedback_length: felt):
end

@external
func submit_feedback{syscall_ptr: felt*, pedersen_ptr, range_check_ptr}(
    token_id: felt, fb_len: felt, fb: felt*
) -> ():
    // Save length in storage.
    feedback_length.write(token_id, fb_len);
    let i = 0;
    while i < fb_len:
        let char_val = [fb + i];
        feedback_char.write(token_id, i, char_val);
        i = i + 1;
    end
    emit FeedbackSubmitted(token_id, fb_len);
    return ();
end

@view
func get_feedback{syscall_ptr: felt*, pedersen_ptr, range_check_ptr}(
    token_id: felt
) -> (fb_len: felt, fb: felt*):
    alloc_locals;
    let (len) = feedback_length.read(token_id);
    let fb_array = alloc();
    let i = 0;
    while i < len:
        let (char_val) = feedback_char.read(token_id, i);
        assert [fb_array + i] = char_val;
        i = i + 1;
    end
    return (fb_len=len, fb=fb_array);
end
