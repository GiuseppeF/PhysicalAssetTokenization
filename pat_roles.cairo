%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func admin(address: felt) -> (is_admin: felt):
end

@event
func AdminGranted(admin: felt):
end

@event
func AdminRevoked(admin: felt):
end

@external
func add_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_admin: felt
):
    let (caller) = get_caller_address();
    let (caller_status) = admin.read(caller);
    assert caller_status = 1, 'Caller is not admin';
    admin.write(new_admin, 1);
    emit AdminGranted(new_admin);
    return ();
end

@external
func remove_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    admin_to_remove: felt
):
    let (caller) = get_caller_address();
    let (caller_status) = admin.read(caller);
    assert caller_status = 1, 'Caller is not admin';
    admin.write(admin_to_remove, 0);
    emit AdminRevoked(admin_to_remove);
    return ();
end
