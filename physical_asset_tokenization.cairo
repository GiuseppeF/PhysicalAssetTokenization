%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp

# ERC20 interface for payments.
@contract_interface
namespace ERC20:
    func transferFrom(sender: felt, recipient: felt, amount: felt) -> (success: felt):
    end
end

# ──────────────────────────────
# ERC721 storage.
@storage_var
func owner_of(token_id: felt) -> (owner: felt):
end

@storage_var
func balance_of(owner: felt) -> (balance: felt):
end

@storage_var
func token_approvals(token_id: felt) -> (approved: felt):
end

@storage_var
func operator_approvals(owner: felt, operator: felt) -> (approved: felt):
end

# ──────────────────────────────
# Additional storage for Physical Asset Tokenization.
@storage_var
func token_counter() -> (count: felt):
end

# Dynamic strings for token name.
@storage_var
func token_name_length(token_id: felt) -> (length: felt):
end

@storage_var
func token_name(token_id: felt, index: felt) -> (char: felt):
end

# Dynamic strings for token description.
@storage_var
func token_description_length(token_id: felt) -> (length: felt):
end

@storage_var
func token_description(token_id: felt, index: felt) -> (char: felt):
end

@storage_var
func token_value(token_id: felt) -> (value: felt):
end

@storage_var
func token_time_validity(token_id: felt) -> (time_validity: felt):
end

@storage_var
func token_state(token_id: felt) -> (state: felt):
end

@storage_var
func token_originator(token_id: felt) -> (originator: felt):
end

@storage_var
func token_WT_address(token_id: felt) -> (wt_address: felt):
end

@storage_var
func token_WT_quote(token_id: felt) -> (quote: felt):
end

@storage_var
func token_selling_price(token_id: felt) -> (price: felt):
end

@storage_var
func token_redemption_nonce(token_id: felt) -> (nonce: felt):
end

@storage_var
func token_active_until(token_id: felt) -> (active_until: felt):
end

# Payment token and owner.
@storage_var
func payment_token_address() -> (addr: felt):
end

@storage_var
func contract_owner() -> (owner: felt):
end

# ──────────────────────────────
# Constants for token states.
const STATE_CREATED = 0
const STATE_WT_SELECTED = 1
const STATE_ACTIVE = 2
const STATE_ABORTED = 3
const STATE_SOLD = 4
const STATE_REDEMPTION_REQUESTED = 5
const STATE_BURNED = 6
const STATE_NEGATIVE_FEEDBACK_ORIGINATOR = 7
const STATE_NEGATIVE_FEEDBACK_OWNER = 8
const STATE_POSITIVE_FEEDBACK = 9

# ──────────────────────────────
# ERC721 Standard Events.
@event
func Transfer(from_: felt, to: felt, tokenId: felt):
end

@event
func Approval(owner: felt, approved: felt, tokenId: felt):
end

@event
func ApprovalForAll(owner: felt, operator: felt, approved: felt):
end

# Additional Events.
@event
func TokenCreated(token_id: felt, originator: felt):
end

@event
func WTSelected(token_id: felt, wt_address: felt, quote: felt):
end

@event
func TokenActivated(token_id: felt, active_until: felt):
end

@event
func TokenAborted(token_id: felt):
end

@event
func TokenPriceSet(token_id: felt, selling_price: felt):
end

@event
func TokenPurchased(token_id: felt, buyer: felt, selling_price: felt):
end

@event
func RedemptionRequested(token_id: felt, redemption_nonce: felt):
end

@event
func TokenBurned(token_id: felt):
end

@event
func NegativeFeedbackOriginator(token_id: felt):
end

@event
func NegativeFeedbackOwner(token_id: felt):
end

@event
func PositiveFeedback(token_id: felt):
end

@event
func PaymentTokenAddressSet(new_address: felt):
end

# ──────────────────────────────
# Internal ERC721 helper: _transfer
func _transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, to: felt, tokenId: felt
) -> ():
    let (from_balance) = balance_of.read(from_);
    balance_of.write(from_, from_balance - 1);
    let (to_balance) = balance_of.read(to);
    balance_of.write(to, to_balance + 1);
    owner_of.write(tokenId, to);
    token_approvals.write(tokenId, 0);
    emit Transfer(from_, to, tokenId);
    return ();
end

# ──────────────────────────────
# ERC721 Standard functions.
@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (balance: felt):
    let (bal) = balance_of.read(owner);
    return (balance=bal);
end

@view
func ownerOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt) -> (owner: felt):
    let (own) = owner_of.read(tokenId);
    return (owner=own);
end

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt, tokenId: felt):
    let (caller) = get_caller_address();
    let (own) = owner_of.read(tokenId);
    assert caller = own, 'Not token owner';
    token_approvals.write(tokenId, to);
    emit Approval(own, to, tokenId);
    return ();
end

@view
func getApproved{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt) -> (approved: felt):
    let (appr) = token_approvals.read(tokenId);
    return (approved=appr);
end

@external
func setApprovalForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(operator: felt, approved: felt):
    let (caller) = get_caller_address();
    operator_approvals.write(caller, operator, approved);
    emit ApprovalForAll(caller, operator, approved);
    return ();
end

@view
func isApprovedForAll{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt, operator: felt) -> (approved: felt):
    let (appr) = operator_approvals.read(owner, operator);
    return (approved=appr);
end

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(from_: felt, to: felt, tokenId: felt):
    let (caller) = get_caller_address();
    let (own) = owner_of.read(tokenId);
    let (appr) = token_approvals.read(tokenId);
    let (is_op) = operator_approvals.read(own, caller);
    if caller != own and caller != appr and is_op != 1:
        assert 0 = 1, 'Not authorized';
    end
    _transfer(from_, to, tokenId);
    return ();
end

@external
func safeTransferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(from_: felt, to: felt, tokenId: felt):
    transferFrom(from_, to, tokenId);
    return ();
end

# ──────────────────────────────
# Additional PhysicalAssetTokenization functions (adapted from the original Solidity logic).

@external
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    payment_addr: felt
):
    token_counter.write(0);
    let (caller) = get_caller_address();
    contract_owner.write(caller);
    payment_token_address.write(payment_addr);
    return ();
end

@external
func createToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name_len: felt, name: felt*,
    description_len: felt, description: felt*,
    value: felt, time_validity: felt
) -> (token_id: felt):
    alloc_locals;
    let (counter) = token_counter.read();
    let new_token_id = counter;
    token_counter.write(counter + 1);
    let (caller) = get_caller_address();
    token_originator.write(new_token_id, caller);
    // Mint ERC721 token.
    owner_of.write(new_token_id, caller);
    let (bal) = balance_of.read(caller);
    balance_of.write(caller, bal + 1);
    // Copy token name.
    token_name_length.write(new_token_id, name_len);
    let i = 0;
    while i < name_len:
         let char_val = [name + i];
         token_name.write(new_token_id, i, char_val);
         i = i + 1;
    end
    // Copy token description.
    token_description_length.write(new_token_id, description_len);
    let j = 0;
    while j < description_len:
         let char_val = [description + j];
         token_description.write(new_token_id, j, char_val);
         j = j + 1;
    end
    token_value.write(new_token_id, value);
    token_time_validity.write(new_token_id, time_validity);
    token_state.write(new_token_id, STATE_CREATED);
    emit TokenCreated(new_token_id, caller);
    emit Transfer(0, caller, new_token_id);
    return (token_id=new_token_id);
end

@external
func WTselection{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt, message_hash: felt, sig_len: felt, signature: felt*, WT_address: felt, msg_value: felt
):
    let (state) = token_state.read(token_id);
    assert state = STATE_CREATED, 'Token not in CREATED state';
    token_WT_address.write(token_id, WT_address);
    token_WT_quote.write(token_id, msg_value);
    token_state.write(token_id, STATE_WT_SELECTED);
    emit WTSelected(token_id, WT_address, msg_value);
    return ();
end

@external
func activateToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt, active_duration: felt
):
    let (caller) = get_caller_address();
    let (wt_addr) = token_WT_address.read(token_id);
    assert caller = wt_addr, 'Caller is not the selected WT';
    let (state) = token_state.read(token_id);
    assert state = STATE_WT_SELECTED, 'Token not in WT_SELECTED state';
    let (current_time) = get_block_timestamp();
    let active_until = current_time + active_duration;
    token_active_until.write(token_id, active_until);
    token_state.write(token_id, STATE_ACTIVE);
    emit TokenActivated(token_id, active_until);
    return ();
end

@external
func abortRequest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
):
    let (caller) = get_caller_address();
    let (originator) = token_originator.read(token_id);
    assert caller = originator, 'Caller is not originator';
    let (state) = token_state.read(token_id);
    assert state = STATE_WT_SELECTED, 'Token not in WT_SELECTED state';
    token_state.write(token_id, STATE_ABORTED);
    token_WT_quote.write(token_id, 0);
    emit TokenAborted(token_id);
    return ();
end

@external
func setTokenSellingPrice{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt, selling_price: felt
):
    let (caller) = get_caller_address();
    let (owner) = owner_of.read(token_id);
    assert caller = owner, 'Caller is not token owner';
    let (state) = token_state.read(token_id);
    assert state = STATE_ACTIVE, 'Token not active';
    token_selling_price.write(token_id, selling_price);
    emit TokenPriceSet(token_id, selling_price);
    return ();
end

@external
func purchaseToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt, price: felt
):
    let (state) = token_state.read(token_id);
    assert state = STATE_ACTIVE, 'Token not active';
    let (set_price) = token_selling_price.read(token_id);
    assert price = set_price, 'Incorrect payment amount';
    let (buyer) = get_caller_address();
    let (seller) = owner_of.read(token_id);
    let (payment_token) = payment_token_address.read();
    let (transfer_result) = ERC20.transferFrom(buyer, seller, price).invoke(contract_address=payment_token);
    assert transfer_result.success = 1, 'ERC20 transfer failed';
    _transfer(seller, buyer, token_id);
    token_state.write(token_id, STATE_SOLD);
    emit TokenPurchased(token_id, buyer, price);
    return ();
end

@external
func redemptionRequest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (redemption_nonce: felt):
    let (state) = token_state.read(token_id);
    assert state = STATE_SOLD, 'Token not sold';
    let redemption_nonce = pedersen(token_id, 123456);
    token_redemption_nonce.write(token_id, redemption_nonce);
    token_state.write(token_id, STATE_REDEMPTION_REQUESTED);
    emit RedemptionRequested(token_id, redemption_nonce);
    return (redemption_nonce=redemption_nonce);
end

@external
func burnToken{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt, message_hash: felt, sig_len: felt, signature: felt*
):
    let (state) = token_state.read(token_id);
    assert state = STATE_REDEMPTION_REQUESTED, 'Token not in redemption phase';
    withdrawQuote(token_id);
    token_state.write(token_id, STATE_BURNED);
    emit TokenBurned(token_id);
    return ();
end

func withdrawQuote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> ():
    token_WT_quote.write(token_id, 0);
    return ();
end

@external
func setNegativeFeedbackByOriginator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (success: felt):
    let (caller) = get_caller_address();
    let (originator) = token_originator.read(token_id);
    assert caller = originator, 'Caller is not originator';
    token_state.write(token_id, STATE_NEGATIVE_FEEDBACK_ORIGINATOR);
    withdrawQuote(token_id);
    emit NegativeFeedbackOriginator(token_id);
    return (success=1);
end

@external
func setNegativeFeedbackByOwner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (success: felt):
    let (caller) = get_caller_address();
    let (owner) = owner_of.read(token_id);
    assert caller = owner, 'Caller is not token owner';
    token_state.write(token_id, STATE_NEGATIVE_FEEDBACK_OWNER);
    withdrawQuote(token_id);
    emit NegativeFeedbackOwner(token_id);
    return (success=1);
end

func setPositiveFeedback{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (success: felt):
    token_state.write(token_id, STATE_POSITIVE_FEEDBACK);
    emit PositiveFeedback(token_id);
    return (success=1);
end

@external
func fallback{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    assert 0 = 1, 'Fallback: direct transfers not allowed';
    return ();
end

@view
func getRedemptionNonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_id: felt
) -> (redemption_nonce: felt):
    let (nonce) = token_redemption_nonce.read(token_id);
    return (redemption_nonce=nonce);
end

@external
func setPaymentTokenAddress{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_payment_token_address: felt
):
    let (caller) = get_caller_address();
    let (owner) = contract_owner.read();
    assert caller = owner, 'Only contract owner can set payment token address';
    payment_token_address.write(new_payment_token_address);
    emit PaymentTokenAddressSet(new_payment_token_address);
    return ();
end
