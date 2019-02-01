include .make

export OWNER ?= rig-test-bucket
export PROFILE ?= default
export PROJECT ?= projectname
export REGION ?= us-east-1
export REPO_BRANCH ?= master
export DATABASE_NAME ?= ${PROJECT}
export CONTAINER_MEMORY ?= 512 #smallest FARGATE value
export HEALTH_CHECK_PATH = /

export AWS_PROFILE=${PROFILE}
export AWS_REGION=${REGION}

export SUBDOMAIN ?= ${REPO}
export KEY_NAME := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/KEY_NAME --output json | jq -r '.Parameter.Value')
export DOMAIN := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/DOMAIN --output json | jq -r '.Parameter.Value')
export DOMAIN_CERT := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/DOMAIN_CERT --output json | jq -r '.Parameter.Value')
export DB_TYPE := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/db/DB_TYPE --output json | jq -r '.Parameter.Value')
export DB_HOST_TYPE := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/db/DB_HOST_TYPE --output json | jq -r '.Parameter.Value')
export EMAIL_ADDRESS := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/EMAIL_ADDRESS --output json | jq -r '.Parameter.Value')
export SLACK_WEBHOOK := $(shell aws ssm get-parameter --name /${OWNER}/${PROJECT}/SLACK_WEBHOOK --output json | jq -r '.Parameter.Value')

create-foundation-deps:
	@echo "Create Foundation S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --region "${REGION}"  2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}  --region "${REGION}" # Foundation configs
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"
	@aws s3api put-bucket-tagging --bucket "rig.${OWNER}.${PROJECT}.${REGION}.foundation.${ENV}" --tagging "TagSet=[{Key=Owner,Value=${OWNER}},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}}]" --region "${REGION}"

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
	@aws s3api put-bucket-tagging --bucket "rig.${OWNER}.${PROJECT}.${REGION}.build" --tagging "TagSet=[{Key=Owner,Value=${OWNER}},{Key=Project,Value=${PROJECT}}]" --region "${REGION}"
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
	@aws s3api put-bucket-tagging --bucket "rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}" --tagging "TagSet=[{Key=Owner,Value=${OWNER}},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}}]" --region "${REGION}"

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
	@aws s3api put-bucket-tagging --bucket "rig.${OWNER}.${PROJECT}.${REGION}.compute.${ENV}" --tagging "TagSet=[{Key=Owner,Value=${OWNER}},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}}]" --region "${REGION}"

delete-compute-deps:
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}

create-db-deps:
ifneq (${DB_TYPE}, none)
	@echo "Create DB S3 bucket: rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}"
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" --region "${REGION}"  2>/dev/null || \
		aws s3 mb s3://rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}  --region "${REGION}" # DB configs
	sleep 60
	@aws s3api put-bucket-versioning --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" --versioning-configuration Status=Enabled --region "${REGION}"
	@aws s3api put-bucket-tagging --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" --tagging "TagSet=[{Key=Owner,Value=${OWNER}},{Key=Project,Value=${PROJECT}},{Key=Environment,Value=${ENV}}]" --region "${REGION}"
endif

delete-db-deps:
ifneq (${DB_TYPE}, none)
	@aws s3api head-bucket --bucket "rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" --region "${REGION}" 2>/dev/null && \
		scripts/empty-s3-bucket.sh rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV} && \
		aws s3 rb --force s3://rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}
endif

create-deps: check-existing-riglet
	@echo "Set/update Project-wide SSM parameters: /${OWNER}/${PROJECT}"
	@read -p 'SSH Key Name: (<ENTER> will keep existing) ' KEY_NAME; \
	        [ -z $$KEY_NAME ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/KEY_NAME" --description "SSH Key Name" --type "String" --value "$$KEY_NAME" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/KEY_NAME" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@read -p 'Domain Name: (<ENTER> will keep existing) ' DOMAIN; \
	        [ -z $$DOMAIN ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/DOMAIN" --description "Domain Name" --type "String" --value "$$DOMAIN" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/DOMAIN" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@read -p 'Domain Cert ID (UUID): (<ENTER> will keep existing) ' DOMAIN_CERT; \
	        [ -z $$DOMAIN_CERT ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/DOMAIN_CERT" --description "Domain Cert Name" --type "String" --value "$$DOMAIN_CERT	" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/DOMAIN_CERT" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@read -p 'Notification Email Address (optional): (<ENTER> will keep existing) ' EMAIL_ADDRESS; \
	        [ -z $$EMAIL_ADDRESS ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/EMAIL_ADDRESS" --description "Notification Email Address" --type "String" --value "$$EMAIL_ADDRESS	" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/EMAIL_ADDRESS" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@read -p 'Notification Slack Webhook (optional): (<ENTER> will keep existing) ' SLACK_WEBHOOK; \
	        [ -z $$SLACK_WEBHOOK ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/SLACK_WEBHOOK" --description "Notification Slack Webhook" --type "String" --value "$$SLACK_WEBHOOK	" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/SLACK_WEBHOOK" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@echo ""
	@echo "Set/update Build SSM parameters: /${OWNER}/${PROJECT}/build"
	@read -p 'GitHub OAuth Token: (<ENTER> will keep existing) ' REPO_TOKEN; \
	        [ -z $$REPO_TOKEN ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/build/REPO_TOKEN" --description "GitHub Repo Token" --type "SecureString" --value "$$REPO_TOKEN" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/build/REPO_TOKEN" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@echo ""
	@echo "Set/update Compute SSM parameters: /${OWNER}/${PROJECT}/compute"
	@read -p 'ECS Host Type (EC2 or FARGATE): (<ENTER> will keep existing) ' ECS_HOST_TYPE; \
	        [ -z $$ECS_HOST_TYPE ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" --description "ECS Host Type" --type "String" --value "$$ECS_HOST_TYPE" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@echo ""
	@echo "Set/update DB SSM parameters: /${OWNER}/${PROJECT}/db"
	@read -p 'DB Type (aurora or couch or none): (<ENTER> will keep existing) ' DB_TYPE; \
	        [ -z $$DB_TYPE ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/db/DB_TYPE" --description "DB Type" --type "String" --value "$$DB_TYPE" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/db/DB_TYPE" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@read -p 'DB Aurora Host Type (provisioned or serverless): (<ENTER> will keep existing) ' DB_HOST_TYPE; \
	        [ -z $$DB_HOST_TYPE ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/db/DB_HOST_TYPE" --description "DB Host Type" --type "String" --value "$$DB_HOST_TYPE" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/db/DB_HOST_TYPE" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}")
	@echo ""
	@echo "Set/update INTEGRATION env SSM parameters: /${OWNER}/${PROJECT}/env/integration"
	@read -p 'Integration Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/integration/db/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (integration)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/env/integration/db/DB_MASTER_PASSWORD" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}" "Key=Environment,Value=integration")
	@echo ""
	@echo "Set/update STAGING env SSM parameters: /${OWNER}/${PROJECT}/env/staging"
	@read -p 'Staging Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/staging/db/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (staging)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/env/staging/db/DB_MASTER_PASSWORD" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}" "Key=Environment,Value=staging")
	@echo ""
	@echo "Set/update PRODUCTION env SSM parameters: /${OWNER}/${PROJECT}/env/production"
	@read -p 'Production Aurora Database Master Password: (<ENTER> will keep existing) ' DB_MASTER_PASSWORD; \
	        [ -z $$DB_MASTER_PASSWORD ] || \
					(aws ssm put-parameter --region ${REGION} --name "/${OWNER}/${PROJECT}/env/production/db/DB_MASTER_PASSWORD" --description "Aurora Database Master Password (production)" --type "SecureString" --value "$$DB_MASTER_PASSWORD" --overwrite && \
					aws ssm add-tags-to-resource --resource-type "Parameter" --resource-id "/${OWNER}/${PROJECT}/env/production/db/DB_MASTER_PASSWORD" --tags "Key=Owner,Value=${OWNER}" "Key=Project,Value=${PROJECT}" "Key=Environment,Value=production")

check-existing-riglet:
	@./scripts/protect-riglet.sh ${OWNER}-${PROJECT} ${REGION} list | [ `wc -l` -gt 0 ] && { echo "Riglet '${OWNER}-${PROJECT}' already exists in this region!"; exit 66; } || true

update-deps: create-deps

# Destroy dependency S3 buckets, only destroy if empty
delete-deps:
	aws ssm delete-parameters --region ${REGION} --names \
		"/${OWNER}/${PROJECT}/KEY_NAME" \
		"/${OWNER}/${PROJECT}/DOMAIN" \
		"/${OWNER}/${PROJECT}/DOMAIN_CERT" \
		"/${OWNER}/${PROJECT}/EMAIL_ADDRESS" \
		"/${OWNER}/${PROJECT}/SLACK_WEBHOOK" \
		"/${OWNER}/${PROJECT}/build/REPO_TOKEN" \
		"/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
		"/${OWNER}/${PROJECT}/db/DB_TYPE" \
		"/${OWNER}/${PROJECT}/db/DB_HOST_TYPE" \
		"/${OWNER}/${PROJECT}/env/integration/db/DB_MASTER_PASSWORD" \
		"/${OWNER}/${PROJECT}/env/staging/db/DB_MASTER_PASSWORD" \
		"/${OWNER}/${PROJECT}/env/production/db/DB_MASTER_PASSWORD"

check-env:
ifndef OWNER
	$(error OWNER is undefined, should be in file .make)
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
ifndef DOMAIN
	$(error DOMAIN is undefined, should be in the SSM parameter store)
endif
ifndef DOMAIN_CERT
	$(error DOMAIN_CERT is undefined, should be in the SSM parameter store)
endif
ifndef KEY_NAME
	$(error KEY_NAME is undefined, should be in the SSM parameter store)
endif
ifndef DB_TYPE
	$(error DB_TYPE is undefined, should be in the SSM parameter store)
endif
	@echo "All required ENV vars set"

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
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" --region ${REGION}

## Create new CF db stack
create-db: create-db-deps upload-db
ifeq (${DB_TYPE}, aurora)
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE} stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
								--region ${REGION} \
								--disable-rollback \
		--template-body "file://cloudformation/db-${DB_TYPE}/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=MasterPassword,ParameterValue=\"$(shell aws ssm get-parameter --region ${REGION}  --output json --name /${OWNER}/${PROJECT}/env/${ENV}/db/DB_MASTER_PASSWORD --with-decryption | jq -r '.Parameter.Value')\"" \
			"ParameterKey=DatabaseName,ParameterValue=${DATABASE_NAME}" \
			"ParameterKey=DbHostType,ParameterValue=/${OWNER}/${PROJECT}/db/DB_HOST_TYPE" \
			"ParameterKey=DbBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" --region ${REGION}
endif
ifeq (${DB_TYPE}, couch)
	@echo "Creating ${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE} stack"
	@aws cloudformation create-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
								--region ${REGION} \
								--disable-rollback \
		--template-body "file://cloudformation/db-${DB_TYPE}/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=SshKeyName,ParameterValue=${KEY_NAME}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-create-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" --region ${REGION}
endif
ifeq (${DB_TYPE}, none)
	@echo "Skip DB creation"
endif

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
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
			"ParameterKey=HealthCheckPath,ParameterValue=${HEALTH_CHECK_PATH}" \
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
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=Repository,ParameterValue=${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
			"ParameterKey=Subdomain,ParameterValue=${SUBDOMAIN}" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=SsmEnvironmentNamespace,ParameterValue=/${OWNER}/${PROJECT}/env/${ENV}" \
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
			"Key=Environment,Value=${ENV}" \
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
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-compute-ecs" --region ${REGION}

update-db: upload-db
ifeq (${DB_TYPE}, aurora)
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE} stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
								--region ${REGION} \
		--template-body "file://cloudformation/db-${DB_TYPE}/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=MasterPassword,ParameterValue=\"$(shell aws ssm get-parameter --region ${REGION} --output json --name /${OWNER}/${PROJECT}/env/${ENV}/db/DB_MASTER_PASSWORD --with-decryption | jq -r '.Parameter.Value')\"" \
			"ParameterKey=DatabaseName,ParameterValue=${DATABASE_NAME}" \
			"ParameterKey=DbHostType,ParameterValue=/${OWNER}/${PROJECT}/db/DB_HOST_TYPE" \
			"ParameterKey=DbBucket,ParameterValue=rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" --region ${REGION}
endif
ifeq (${DB_TYPE}, couch)
	@echo "Updating ${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE} stack"
	@aws cloudformation update-stack --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
								--region ${REGION} \
		--template-body "file://cloudformation/db-${DB_TYPE}/main.yaml" \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters \
			"ParameterKey=FoundationStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-foundation" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=Environment,ParameterValue=${ENV}" \
			"ParameterKey=SshKeyName,ParameterValue=${KEY_NAME}" \
		--tags \
			"Key=Environment,Value=${ENV}" \
			"Key=Owner,Value=${OWNER}" \
			"Key=Project,Value=${PROJECT}"
	@aws cloudformation wait stack-update-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" --region ${REGION}
endif
ifeq (${DB_TYPE}, none)
	@echo "Skip DB update"
endif

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
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
			"ParameterKey=HealthCheckPath,ParameterValue=${HEALTH_CHECK_PATH}" \
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
			"ParameterKey=PublicDomainName,ParameterValue=${DOMAIN}" \
			"ParameterKey=Repository,ParameterValue=${OWNER}-${PROJECT}-${REPO}-${REPO_BRANCH}-ecr-repo" \
			"ParameterKey=ApplicationName,ParameterValue=${REPO}" \
			"ParameterKey=ContainerPort,ParameterValue=${CONTAINER_PORT}" \
			"ParameterKey=ContainerMemory,ParameterValue=${CONTAINER_MEMORY}" \
			"ParameterKey=ListenerRulePriority,ParameterValue=${LISTENER_RULE_PRIORITY}" \
			"ParameterKey=EcsHostType,ParameterValue=/${OWNER}/${PROJECT}/compute/ECS_HOST_TYPE" \
			"ParameterKey=Owner,ParameterValue=${OWNER}" \
			"ParameterKey=Subdomain,ParameterValue=${SUBDOMAIN}" \
			"ParameterKey=ComputeStackName,ParameterValue=${OWNER}-${PROJECT}-${ENV}-compute-ecs" \
			"ParameterKey=SsmEnvironmentNamespace,ParameterValue=/${OWNER}/${PROJECT}/env/${ENV}" \
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
		--stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
		--output json \
		--query "Stacks[][StackStatus] | []" | jq

## Print DB stack's outputs
outputs-db:
	@aws cloudformation describe-stacks \
                --region ${REGION} \
		--stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" \
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
ifneq (${DB_TYPE}, none)
	@if ${MAKE} .prompt-yesno message="Are you sure you wish to delete the ${ENV} DB Stack?"; then \
		aws cloudformation delete-stack --region ${REGION} --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}"; \
		aws cloudformation wait stack-delete-complete --stack-name "${OWNER}-${PROJECT}-${ENV}-db-${DB_TYPE}" --region ${REGION}; \
	fi
endif

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
	@aws s3 cp --recursive cloudformation/app/ s3://rig.${OWNER}.${PROJECT}.${REGION}.app.${ENV}/templates/

## Upload Compute ECS Templates
upload-compute:
	@aws s3 cp --recursive cloudformation/compute-ecs/ s3://rig.${OWNER}.${PROJECT}.${REGION}.compute-ecs.${ENV}/templates/

upload-db:
ifneq (${DB_TYPE}, none)
	@aws s3 cp --recursive cloudformation/db-${DB_TYPE}/ s3://rig.${OWNER}.${PROJECT}.${REGION}.db-${DB_TYPE}.${ENV}/templates/
endif

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
