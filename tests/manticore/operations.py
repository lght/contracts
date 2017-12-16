from manticore.seth import ManticoreEVM, ABI

m = ManticoreEVM()

source_code = file("../../Operations.sol").read()
bytecode = m.compile(source_code)

grand_owner = m.create_account(balance=10000)
contract_account = m.create_contract(owner=grand_owner,
                                            balance=0,
                                            init=bytecode)

## Add client
client_owner = m.create_account(balance=100000)
add_client_owner = ABI.make_function_call("addClient(bytes32,address)", "parity-1.7.3", client_owner)
m.transaction(  caller=grand_owner,
                    address=contract_account,
                    value=0,
                    data=add_client_owner
                )
