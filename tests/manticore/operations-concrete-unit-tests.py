from manticore.ethereum import ManticoreEVM
################ Script #######################

seth = ManticoreEVM()
seth.verbosity(0)

print("[+] Setup the target contract")
## Load target contract solidity source
operations_src = open("../../Operations.sol").read()

## Create owner account
owner_account = seth.create_account(balance=10000000000000000)

## Create contract account
contract_account = seth.solidity_create_contract(operations_src, owner_account, balance=1000000) 

print("[+] Setup the test contract")
## Load test contract solidity source
test_src = open("./contracts/TestOperations.sol").read()

## Create test owner account
test_owner_account = seth.create_account(balance=100000000000)

## Create contract account
test_contract_account = seth.solidity_create_contract(test_src, test_owner_account, balance=10000)

print("\t Setting target contract address")
test_contract_account.set_target_contract(contract_account)

print("\t Testing target contract init")
test_contract_account.test_init()

print(" contract_account %X"% (contract_account))
print(" test_contract_account %X"% (test_contract_account))


client = "parity"
release = "1.8.2"
print(" Testing target contract has latest release for")
print("\t client: %s\n\t release: %s"% (client, release))
     

## Encode call to isLatest() to pass to our test contract
is_latest_call = seth.make_function_call("isLatest(bytes32,bytes32)", client, release)
## Make call to the test contract,
##   delegate calls target_contract.isLatest(client, release)
is_latest_ret = test_contract_account.test_is_latest_returns_true(is_latest_call)

is_latest_error = "isLatest should return true for client: %s, release: %s"% (client, release)

assert(is_latest_ret == True, is_latest_error)
