include ../.env

install:
	@forge install cyfrin/foundry-devops
	@forge install smartcontractkit/chainlink-brownie-contracts
	@forge install openzeppelin/openzeppelin-contracts

deploy-nexus:
	@forge script script/deploy.s.sol:DeployAll --via-ir --broadcast \
	--rpc-url ${NEXUS_RPC_URL} --private-key ${NEXUS_KEY} \
	--verify --verifier blockscout --verifier-url ${NEXUS_VERIFIER} -vv

deploy-sepolia:
	@forge script script/deploy.s.sol:DeployAll --via-ir --broadcast \
	--rpc-url ${SEPOLIA_RPC_URL} --private-key ${KEY} \
	--verify --verifier blockscout --verifier-url ${SEPOLIA_VERIFIER} -vv
BSigner:
	@forge script script/interactions.s.sol:faceVerification --via-ir --broadcast \
	--rpc-url ${SEPOLIA_RPC_URL} --private-key ${KEY}