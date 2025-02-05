%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.crypto.signature import verify

/// verify_signature:
/// Given a public key, a message hash, and signature components (r and s),
/// returns 1 if the signature is valid and 0 otherwise.
@external
func verify_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pub_key: felt, msg_hash: felt, sig_r: felt, sig_s: felt
) -> (is_valid: felt):
    // Uses StarkNet’s native verify function.
    let is_valid = verify(pub_key, msg_hash, (sig_r, sig_s));
    return (is_valid=is_valid);
end

/// get_message_hash:
/// Computes a Pedersen hash from a dynamic array of felts representing the message.
/// This is a production‑grade loop that processes the message array element by element.
@external
func get_message_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    len: felt, message: felt*
) -> (hash: felt):
    alloc_locals;
    let hash_val = 0;
    let i = 0;
    while i < len:
        // Read the i-th element from the calldata array.
        let m_i = [message + i];
        // Update hash_val using the pedersen built‑in.
        let new_hash = pedersen(hash_val, m_i);
        hash_val = new_hash;
        i = i + 1;
    end
    return (hash=hash_val);
end

/// to_stark_signed_message_hash:
/// Converts a message hash into the StarkNet‑specific signed hash format
/// by using a standard prefix (for example, the ASCII for "SK").
@external
func to_stark_signed_message_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    msg_hash: felt
) -> (stark_hash: felt):
    let prefix = 0x534B; // 'SK' in hex.
    let stark_hash = pedersen(prefix, msg_hash);
    return (stark_hash=stark_hash);
end

/// split_signature:
/// Given a signature array and its length, splits the signature into its (r, s) components.
/// The function asserts that the signature length is exactly 2.
@external
func split_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sig_len: felt, signature: felt*
) -> (sig_r: felt, sig_s: felt):
    assert sig_len = 2, 'Invalid signature length';
    let sig_r = [signature];       // First element of the array.
    let sig_s = [signature + 1];     // Second element of the array.
    return (sig_r=sig_r, sig_s=sig_s);
end

/// check_signature:
/// Checks that a given signature is valid for the provided message and public key.
/// This function computes the message hash from a dynamic array, splits the signature,
/// and then calls verify_signature.
@external
func check_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pub_key: felt, msg_len: felt, message: felt*, sig_len: felt, signature: felt*
) -> (is_valid: felt):
    let (msg_hash) = get_message_hash(msg_len, message);
    let (sig_r, sig_s) = split_signature(sig_len, signature);
    let (valid) = verify_signature(pub_key, msg_hash, sig_r, sig_s);
    return (is_valid=valid);
end
