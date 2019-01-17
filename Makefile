include .make

export DOMAIN ?= example.tld
export KEY_NAME ?= ""
export OWNER ?= rig-test-bucket
export PROFILE ?= default
export PROJECT ?= projectname
export REGION ?= us-east-1
export REPO_BRANCH ?= master
export DOMAIN_CERT ?= ""
export DATABASE_NAME ?= ${PROJECT}

export AWS_PROFILE=${PROFILE}
export AWS_REGION=${REGION}

export SUBDOMAIN ?= ${REPO}


create-foundation-deps:
	@echo "Create Foundation S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --region "${REGION}"  2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}  --region "${REGION}" # Foundation configs
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"

delete-foundation-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}

create-build-deps:
	@echo "Create Build Artifacts S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.build"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.build" --region "${REGION}" 2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.build --region "${REGION}" # Build artifacts, etc
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.build" --versioning-configuration Status=Enabled --region "${REGION}"
	sleep 60
	@aws s3 website s3://rig.${OWNER}.${PROJECT}.${REGION}.build/ --index-document index.html --region "${REGION}"

delete-build-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.build" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.build && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.build

create-app-deps:
	@echo "Create App S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" --region "${REGION}" 2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV} --region "${REGION}" # Storage for InfraDev
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"

delete-app-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}

create-compute-deps:
	@echo "Create Compute S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" --region "${REGION}"  2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}  --region "${REGION}" # Compute configs
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"

delete-compute-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}

create-db-deps:
	@echo "Create DB S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}" --region "${REGION}"  2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}  --region "${REGION}" # DB configs
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"

delete-db-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}

create-deps: check-existing-riglet
	@echo "Set/update SSM build secrets and parameters: /${OWNER}/${PROJECT}/build"
	@read -p 'GitHub OAuth Token: (<ENTER> will keep existing) ' REPO_TOKEN; \
	        [ -z $$REPO_TOKEN ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/build/REPO_TOKEN" --description "GitHub Repo Token" --type "SecureString" --value "$$REPO_TOKEN" --overwrite
	@echo ""
	@echo "Set/update INTEGRATION env SSM parameters: /${OWNER}/${PROJECT}/env/integration"
	@read -p 'Integration Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/db/integration/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (integration)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite
	@read -p 'Integration Application Database User Password (make same as above): (<ENTER> will keep existing) ' APPLICATION_DATABASE_PASSWORD; \
	        [ -z $$APPLICATION_DATABASE_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/integration/APPLICATION_DATABASE_PASSWORD" --description "Application Database User Password (integration)" --type "SecureString" --value "$$APPLICATION_DATABASE_PASSWORD" --overwrite
	@echo ""
	@echo "Set/update STAGING env SSM parameters: /${OWNER}/${PROJECT}/env/staging"
	@read -p 'Staging Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/db/staging/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (staging)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite
	@read -p 'Staging Application Database User Password (make same as above): (<ENTER> will keep existing) ' APPLICATION_DATABASE_PASSWORD; \
	        [ -z $$APPLICATION_DATABASE_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/staging/APPLICATION_DATABASE_PASSWORD" --description "Application Database User Password (staging)" --type "SecureString" --value "$$APPLICATION_DATABASE_PASSWORD" --overwrite
	@echo ""
	@echo "Set/update PRODUCTION env SSM parameters: /${OWNER}/${PROJECT}/env/production"
	@read -p 'Production Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/db/production/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (production)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite
	@read -p 'Production Application Database User Password (make same as above): (<ENTER> will keep existing) ' APPLICATION_DATABASE_PASSWORD; \
	        [ -z $$APPLICATION_DATABASE_PASSWORD ] || aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/production/APPLICATION_DATABASE_PASSWORD" --description "Application Database User Password (production)" --type "SecureString" --value "$$APPLICATION_DATABASE_PASSWORD" --overwrite

check-existing-riglet:
	@./scripts/protect-riglet.sh ${OWNER}-${PROJECT} ${REGION} list | [ `wc -l` -gt 0 ] && { echo "Riglet '${OWNER}-${PROJECT}' already exists in this region!"; exit 66; } || true

update-deps: create-deps

# Destroy dependency S3 buckets, only destroy if empty
delete-deps:
	aws ssm delete-parameters --region ${REGION} --names \
		"/${OWNER}/${PROJECT}/build/REPO_TOKEN" \
		"/${OWNER}/${PROJECT}/db/integration/DB_MASTER_PASSWORD" \
		"/${OWNER}/${PROJECT}/db/staging/DB_MASTER_PASSWORD" \
		"/${OWNER}/${PROJECT}/db/production/DB_MASTER_PASSWORD" \
		"/${OWNER}/${PROJECT}/env/integration/APPLICATION_DATABASE_PASSWORD" \
		"/${OWNER}/${PROJECT}/env/staging/APPLICATION_DATABASE_PASSWORD" \
		"/${OWNER}/${PROJECT}/env/production/APPLICATION_DATABASE_PASSWORD"

## Creates Foundation and Build

## Creates a new CF stack
create-foundation: create-foundation-deps upload-foundation
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-foundation stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" \
                --region ${REGION} \
		--template-body "file://cloudformation/foundation/main.yaml" \
		--disable-rollback \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" \
			"ParameterKey=ProjectName,ParameterValue=${PROJECT}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=EmailAddress,ParameterValue=${EMAIL_ADDRESS}" \
			"ParameterKey=DomainCertGuid,ParameterValue=${DOMAIN_CERT}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" --region ${REGION}

## Create new CF compute stack
create-compute: create-compute-deps upload-compute
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-compute-ecs stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
                --region ${REGION} \
                --disable-rollback \
		--template-body "file://cloudformation/compute-ecs/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=ComputeBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=SshKeyName,ParameterValue=${KEY_NAME}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" --region ${REGION}

## Create new CF db stack
create-db: create-db-deps upload-db
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-db-aurora stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" \
                --region ${REGION} \
                --disable-rollback \
		--template-body "file://cloudformation/db-aurora/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=MasterPassword,ParameterValue=\"$(shell aws ssm get-parameter --region ${REGION}  --output json --name /${OWNER}/${PROJECT}/db/${ENV}/DB_MASTER_PASSWORD --with-decryption | jq -r '.Parameter.Value')\"" \
			"ParameterKey=DatabaseName,ParameterValue=${DATABASE_NAME}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" --region ${REGION}

## Create new CF environment stacks
create-environment: create-foundation create-compute create-db create-app-deps upload-app

## Create new CF Build pipeline stack
create-build: create-build-deps upload-build upload-lambdas
	@echo "Creating ${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH} stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" \
                --region ${REGION} \
                --disable-rollback \
		--template-body "file://cloudformation/build/deployment-pipeline.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=AppStackName,ParameterValue=${OWNER}-${PROJECT}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=InfraDevBucketBase,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.app" \
			"ParameterKey=BuildArtifactsBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.build" \
			"ParameterKey=GitHubRepo,ParameterValue=${REPO}" \
			"ParameterKey=GitHubBranch,ParameterValue=${REPO_BRANCH}" \
			"ParameterKey=GitHubToken,ParameterValue=$(shell aws ssm get-parameter --region ${REGION} --output json --name /${OWNER}/${PROJECT}/build/REPO_TOKEN --with-decryption | jq -r '.Parameter.Value')" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
			"ParameterKey=Subdomain,ParameterValue=${SUBDOMAIN}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
			"ParameterKey=SsmNamespacePrefix,ParameterValue=/${OWNER}/${PROJECT}" \
			"ParameterKey=SlackWebhook,ParameterValue=${SLACK_WEBHOOK}" \
			"ParameterKey=Project,ParameterValue=${PROJECT}" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" --region ${REGION}

## Create new CF app stack
create-app: create-app-deps upload-app
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH} stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" \
                --region ${REGION} \
                --disable-rollback \
		--template-body "file://cloudformation/app/app.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=InfraDevBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=Repository,ParameterValue=${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" --region ${REGION}

create-bastion:
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-bastion stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-bastion" \
                --region ${REGION} \
                --disable-rollback \
		--template-body "file://cloudformation/bastion/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=SshKeyName,ParameterValue=${KEY_NAME}" \
			"ParameterKey=Ami,ParameterValue=$(shell aws ec2 describe-images --region ${REGION} --owners 137112412989 --output json | jq '.Images[] | {Name, ImageId} | select(.Name | contains("amzn-ami-hvm")) | select(.Name | contains("gp2")) | select(.Name | contains("rc") | not)' | jq -s 'sort_by(.Name) | reverse | .[0].ImageId' -r)" \
			"ParameterKey=IngressCidr,ParameterValue=$(shell dig +short myip.opendns.com @resolver1.opendns.com)/32" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-bastion" --region ${REGION}

## Updates existing Foundation CF stack
update-foundation: upload-foundation
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-foundation stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" \
                --region ${REGION} \
		--template-body "file://cloudformation/foundation/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" \
			"ParameterKey=ProjectName,ParameterValue=${PROJECT}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=EmailAddress,ParameterValue=${EMAIL_ADDRESS}" \
			"ParameterKey=DomainCertGuid,ParameterValue=${DOMAIN_CERT}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" --region ${REGION}

## Update CF compute stack
update-compute: upload-compute
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-compute-ecs stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
                --region ${REGION} \
		--template-body "file://cloudformation/compute-ecs/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" \
			"ParameterKey=SshKeyName,ParameterValue=${KEY_NAME}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" --region ${REGION}

update-db: upload-db
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-db-aurora stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" \
                --region ${REGION} \
		--template-body "file://cloudformation/db-aurora/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=MasterPassword,ParameterValue=\"$(shell aws ssm get-parameter --region ${REGION} --output json --name /${OWNER}/${PROJECT}/db/${ENV}/DB_MASTER_PASSWORD --with-decryption | jq -r '.Parameter.Value')\"" \
			"ParameterKey=DatabaseName,ParameterValue=${DATABASE_NAME}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" --region ${REGION}

## Update CF environment stacks
update-environment: update-foundation update-compute update-db upload-app

## Update existing Build Pipeline CF Stack
update-build: upload-build upload-lambdas
	@echo "Updating ${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH} stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" \
                --region ${REGION} \
		--template-body "file://cloudformation/build/deployment-pipeline.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=AppStackName,ParameterValue=${OWNER}-${PROJECT}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=InfraDevBucketBase,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.app" \
			"ParameterKey=BuildArtifactsBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.build" \
			"ParameterKey=GitHubRepo,ParameterValue=${REPO}" \
			"ParameterKey=GitHubBranch,ParameterValue=${REPO_BRANCH}" \
			"ParameterKey=GitHubToken,ParameterValue=$(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/build/REPO_TOKEN --output json --with-decryption | jq -r '.Parameter.Value')" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
			"ParameterKey=Subdomain,ParameterValue=${SUBDOMAIN}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
			"ParameterKey=SsmNamespacePrefix,ParameterValue=/${OWNER}/${PROJECT}" \
			"ParameterKey=SlackWebhook,ParameterValue=${SLACK_WEBHOOK}" \
			"ParameterKey=Project,ParameterValue=${PROJECT}" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
		--tags \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" --region ${REGION}

## Update App CF stack
update-app: upload-app
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH} stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" \
                --region ${REGION} \
		--template-body "file://cloudformation/app/app.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=InfraDevBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" \
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=Repository,ParameterValue=${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-app" --region ${REGION}

## Print Foundation stack's status
status-foundation:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print Foundation stack's outputs
outputs-foundation:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Print Compute stack's status
status-compute:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print Compute stack's outputs
outputs-compute:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Print DB stack's status
status-db:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print DB stack's outputs
outputs-db:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Print Environment stacks' status
status-environment: status-foundation status-compute status-db

## Print Environment stacks' output
outputs-environment: outputs-foundation outputs-compute outputs-db

## Print build pipeline stack's status
status-build:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq


## Print build pipeline stack's outputs
outputs-build:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Print app stack's status
status-app:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print app stack's outputs
outputs-app:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "$${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Print Bastion stack's status
status-bastion:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-bastion" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print Bastion stack's outputs
outputs-bastion:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-bastion" \
		--output json \
		--query "Stacks[][Outputs] | []" | jq

## Deletes the Foundation CF stack
delete-foundation-stack:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${ENV} Foundation Stack?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-foundation" --region ${REGION}; \
	fi

delete-foundation: delete-foundation-stack delete-foundation-deps

## Deletes the Compute CF stack
delete-compute-stack:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${ENV} Compute Stack?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" --region ${REGION}; \
	fi

delete-compute: delete-compute-stack delete-compute-deps

## Deletes the DB CF stack
delete-db-stack:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${ENV} DB Stack?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-aurora" --region ${REGION}; \
	fi

delete-db: delete-db-stack delete-db-deps

## Deletes the Environment CF stacks
delete-environment: delete-db delete-compute delete-foundation delete-app-deps

## Deletes the build pipeline CF stack
delete-build-stack:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${PROJECT} Pipeline Stack for repo: ${REPO}?"; then \
		aws ecr batch-delete-image --region ${REGION} --repository-name ${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo --image-ids '$(shell aws ecr list-images --region ${REGION} --repository-name ${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo --query 'imageIds[*]' --output json)'; \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-build-${REPO}-${REPO_BRANCH}" --region ${REGION}; \
	fi

delete-build: delete-build-stack delete-build-deps

## Deletes the app CF stack
delete-app:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the App Stack for environment: ${ENV} repo: ${REPO}?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-app-${REPO}-${REPO_BRANCH}" --region ${REGION}; \
	fi

## Deletes the Bastion CF stack
delete-bastion:
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${ENV} Bastion Stack?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-bastion"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-bastion" --region ${REGION}; \
	fi

## Upload CF Templates to S3
# Uploads foundation templates to the Foundation bucket
upload-foundation:
	@aws s3 cp --recursive cloudformation/foundation/ s3://rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}/templates/

## Upload CF Templates for project
# Note that these templates will be stored in your InfraDev Project **shared** bucket:
upload-app:
	@aws s3 cp --recursive cloudformation/app/ s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}/templates/
	@pwd=$(shell pwd)
	@cd cloudformation/app/ && zip templates.zip *.yaml
	@cd ${pwd}
	@aws s3 cp cloudformation/app/templates.zip s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}/templates/
	@rm -rf cloudformation/app/templates.zip
	@aws s3 cp cloudformation/app/app.yaml s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}/templates/

## Upload Compute ECS Templates
upload-compute:
	@aws s3 cp --recursive cloudformation/compute-ecs/ s3://rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}/templates/

upload-db:
	@aws s3 cp --recursive cloudformation/db-aurora/ s3://rig.${OWNER}.${PROJECT}.${REGION}.db-aurora.${ENV}/templates/

## Upload Build CF Templates
upload-build:
	@aws s3 cp --recursive cloudformation/build/ s3://rig.${OWNER}.${PROJECT}.${REGION}.build/templates/

upload-lambdas:
	@pwd=$(shell pwd)
	@cd lambdas && zip ${OWNER}-${PROJECT}-handlers.zip *.js
	@cd ${pwd}
	@aws s3 cp lambdas/${OWNER}-${PROJECT}-handlers.zip s3://rig.${OWNER}.${PROJECT}.${REGION}.build/lambdas/
	@rm lambdas/${OWNER}-${PROJECT}-handlers.zip

## Turns ON termination protection for riglet identified in .make file.
protect-riglet:
	@scripts/protect-riglet.sh ${OWNER}-${PROJECT} ${REGION} enable

## Turns OFF termination protection for riglet identified in .make file
un-protect-riglet:
	@scripts/protect-riglet.sh ${OWNER}-${PROJECT} ${REGION} disable

## Lists riglet (parent) stacks
list-riglet-stacks:
	@scripts/protect-riglet.sh ${OWNER}-${PROJECT} ${REGION} list

check-env:
ifndef OWNER
	$(error OWNER is undefined, should be in file .make)
endif
ifndef DOMAIN
	$(error DOMAIN is undefined, should be in file .make)
endif
ifndef KEY_NAME
	$(error KEY_NAME is undefined, should be in file .make)
endif
ifndef PROFILE
	$(error PROFILE is undefined, should be in file .make)
endif
ifndef PROJECT
	$(error PROJECT is undefined, should be in file .make)
endif
ifndef REGION
	$(error REGION is undefined, should be in file .make)
endif
ifndef DOMAIN_CERT
	$(error DOMAIN_CERT is undefined, should be in file .make)
endif
	@echo "All required ENV vars set"

## Print this help
help:
	@awk -v skip=1 \
		'/^##/ { sub(/^[#[:blank:]]*/, "", $$0); doc_h=$$0; doc=""; skip=0; next } \
		 skip  { next } \
		 /^#/  { doc=doc "\n" substr($$0, 2); next } \
		 /:/   { sub(/:.*/, "", $$0); printf "\033[33m\033[01m%-30s\033[0m\033[1m%s\033[0m %s\n\n", $$0, doc_h, doc; skip=1 }' \
		${MAKEFILE_LIST}


.CLEAR=\x1b[0m
.BOLD=\x1b[01m
.RED=\x1b[31;01m
.GREEN=\x1b[32;01m
.YELLOW=\x1b[33;01m

# Re-usable target for yes no prompt. Usage: make .prompt-yesno message="Is it yes or no?"
# Will exit with error if not yes
.prompt-yesno:
	$(eval export RESPONSE="${shell read -t30 -n1 -p "${message} [Yy]: " && echo "$$REPLY" | tr -d '[:space:]'}")
	@case ${RESPONSE} in [Yy]) \
			echo "\n${.GREEN}[Continuing]${.CLEAR}" ;; \
		*) \
			echo "\n${.YELLOW}[Cancelled]${.CLEAR}" && exit 1 ;; \
	esac

#.check-for-delete-bucket-jar:
#	@if [ ! -f DeleteVersionedS3Bucket.jar ]; then \
#		curl -O https://s3.amazonaws.com/baremetal-rig-helpers/DeleteVersionedS3Bucket.jar; \
#	fi

.make:
	@touch .make
	@scripts/build-dotmake.sh

.DEFAULT_GOAL := help
.PHONY: help
.PHONY: deps check-env get-ubuntu-ami .prompt-yesno
