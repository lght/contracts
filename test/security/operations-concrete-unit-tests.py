from seth import ManticoreEVM, EVMContract
################ Script #######################

seth = ManticoreEVM()
seth.verbosity(0)

print("[+] Setup the target contract")
## Load compiled target contract and solidity source
## create with:
##   solc --combined-json srcmap,srcmap-runtime,bin,hashes -o <out-dir> Contract.sol
##   mv <out-dir>/combined.json <out-dir>/Contract.json
contract_json = open("./build/json/Operations.json").read()
contract_src = open("./contracts/Operations.sol").read()

## Create owner account
owner_account = seth.create_account(balance=10000000000000000)

## Create contract account
contract_account = seth.create_contract_account(owner_account, contract_src, contract_json) 

print("[+] Setup the test contract")
## Load compiled test contract and solidity source
## create with:
##   solc --combined-json srcmap,srcmap-runtime,bin,hashes -o <out-dir> Contract.sol
##   mv <out-dir>/combined.json <out-dir>/Contract.json
test_json = open("./build/json/TestOperations.json").read()
test_src = open("./contracts/TestOperations.sol").read()

## Create test owner account
test_owner_account = seth.create_account(balance=100000000000)

## Create contract account
test_contract_account = seth.create_contract_account(test_owner_account, test_src, test_json)

print("\t Setting target contract address")
test_contract_account.set_target_contract(contract_account)

print("\t Testing target contract init")
test_contract_account.test_init()

print(" contract_account %X"% (contract_account))
print(" test_contract_account %X"% (test_contract_account))
