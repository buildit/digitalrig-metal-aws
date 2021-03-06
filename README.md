# AWS Bare Metal Rig

This codebase contains code to create and maintain a CloudFormation, AWS CodePipeline/CodeBuild/CodeDeploy powered Rig on AWS.  This riglet is based completely on AWS technologies.  The idea is that it should require nothing but the AWS CLI to fire up an operational riglet with appropriate environments and a ready-to-execute build pipeline.

This repository is intended to be a reference implementation and act as the latest and greatest version of the AWS Bare Metal Rig

## The big picture(s)

Bookit was rebooted in Sept 2017, and we decided to start from scratch.  We did decide to use the [Bookit Riglet (implementation of Bare Metal Rig)](https://github.com/buildit/bookit-riglet) as a starting point however.  As additional features were branched and prototyped, we decided to clone the [bookit-infrastructure](https://github.com/buildit/bookit-infrastructure) and remove any references to Bookit.

Typically, new projects would clone/fork this repo as a starting point for their own AWS Bare Metal Rig instance.

This guide has all the steps for creating an "AWS Bare Metal riglet instance".  The riglet is capable of doing builds, pushing to docker and deploying the docker images using blue/green deployment in to ECS.

The major components of this riglet are:

* A "foundational" stack running in Amazon:  1 of these is created for each environment (integration, staging, production, etc)
  * a VPC with the appropriate network elements (gateways, NAT)
  * a shared Application Load Balancer (ALB) - listens on ports 80 & 443
  * a shared EC2 Container Server (ECS) Cluster (using either EC2 hosts or Fargate).
  * (optional) an RDS Aurora or CouchDB Database
  * 4 shared S3 buckets to store CloudFormation templates and scripts
    * a "foundation" bucket to store templates associated w/ the foundational stack
    * a "build" bucket to store build artifacts for the CodePipeline below (this is shared across all pipelines)
    * an "app" bucket to store templates associated w/ the app stack below
* A "deployment-pipeline" stack: 1 stack per branch per repo
  * an ECS Repository (ECR)
  * a CodeBuild build - see buildspec.yml in the project
    * Installs dependencies (JDK, Node, etc)
    * Executes build (download libraries, build, test, lint, package docker image)
    * Pushes the image to the ECR
  * Two CodePipeline pipelines that do the following:
    * Build Pipeline
      * Polls for changes to the branch
      * Executes the CodeBuild
      * Builds Docker image
    * Deploy Pipeline
      * Listens for recently completed builds and updated application templates in S3
      * Creates/Updates the "app" stack below for the integration environment
      * This also deploys the built Docker image to the ECS cluster
      * Creates/Updates the "app" stack below for the staging environment
      * Creates/Updates an "app" stack change set for the production environment
      * Waits for review/approval
      * Executes the "app" stack change set which creates/updates/deploys for the production environment
  * IAM roles to make it all work
* An "app" stack: 1 stack per branch per repo per environment - requires "foundation" stack to already exist and ECR repository with built images
  * a ALB target group
  * 2 ALB listener rules (http & https) that route to the target group based on the HOST header
  * a Route53 DNS entry pointing to the ALB
  * (optionally) a Route53 DNS entry without the environment name (for production)
  * an ECS Service which ties the Target Group to the Task Definition
  * an ECS Task Definition which runs the specific tag Docker image
  * IAM roles to make it all work

The all infrastructure are set up and maintained using AWS CloudFormation.  CodeBuild is configured simply by updating the buildspec.yml file in each application project.

The whole shebang:

![alt text](docs/architecture/diagrams/digitalrig-metal-aws-riglet-aws-hi-level.png)

Single Environment (more detail):

![alt text](docs/architecture/diagrams/aws-bare-foundation.png)

CodePipeline (more detail):

![Code Pipeline](docs/architecture/diagrams/digitalrig-metal-aws-riglet-codepipeline-detail.png)

## Architectural Decisions

We are documenting our decisions [here](docs/architecture/decisions)

## Architecture specifics

### Foundation

A "standard" riglet starts with a foundation:  three identical _Virtual Private Cloud_s (VPC), each
representing an _environment_: _integration_ testing, _staging_ and _production_.  Each VPC has separate
pairs of private subnets for application and database instances, with appropriate NATs and routing to
give EC2 instances access to the internet.

Into each VPC, the following are allocated:

* a single EC2 instance running CouchDb (launched from a custom AMI)
* (ECS_HOST_TYPE = ECS) a configurable number of instances to comprise the EC2 Container Service (ECS) cluster
* (ECS_HOST_TYPE = FARGATE) ECS service/tasks spread across the private subnets

An Application Load Balancer (ALB) is also configured for the VPC.  This ALB is configured at build/deployment
time to route traffic to the appropriate system.

ALB and application security groups are created is defined to disallow traffic to the ECS cluster from
anywhere but the ALB, and over appropriate ports.

An SNS "operations" topic is created, with the expectation that pertinent error messages and alarm message
will be published there. An email address can optionally be subscribed to this topic at foundation creation time.

> Unfortunately, Route53 External Health Check can only be defined in us-east-1, and won't trigger when
> this riglet runs in any other region.

### Compute Layer

The "compute layer" in this rig is an ECS Cluster.  ECS allows you to deploy arbitrary code in Docker images,
and ECS handles the allocation of containers to run the images (a process known as "scheduling").

The Docker containers are hosted in what ECS calls "Tasks", and the Tasks are managed by "Services".  A
Task can be defined to run one or more containers.  

A Service knows what version of a Task's definition is running at a given time, and how many instances
(desired count) of the Task should be maintained.  The running Tasks are automatically allocated to
the appropriate ECS cluster member.

### Database Layer

The "database layer" in this rig is optional and can either be RDS Aurora (MySQL compatible) or CouchDb
deployed on an EC2 instance, running in a dedicated subnet.  The EC2 instance is created from an AMI
that was created from a running CouchDb instance in the old Rig 2.0 based riglet.  At instantiation time,
a cron job is defined to back up the database files to an appropriate S3 bucket.

Security groups are created that allow access to the Database only from the application group and only
over the Database port.

### Build "Layer"

OK, it's not really a "layer", but the final piece of the riglet is the build pipeline.  In this case
we use AWS CodePipeline and CodeBuild to define and execute the pipeline.  Builds are triggered by
changes to either the source code of the application(s) or by changes to the Cfn templates that define
how applications are deployed.

Speaking of application deployments, those are also accomplished using Cfn, but the creation of the
application Cfn stacks is automated in the build pipelines.  (_Note:_  one will seldom, if ever, create
an application stack by hand.  However, the capability is there, and might be used to create a load
testing environment with selected Docker images deployed.)

An SNS "build" topic is created, and the build pipeline is configured to publish CodeBuild success/failure
messages there. An email address can optionally be subscribed to this topic at foundation creation time.

---

## Setup

_Please read through and understand these instructions before starting_.  There is a lot of automation, but there are also _a lot_ of details.
Approaching things incorrectly can result in a non-running riglet that can be tricky to debug if you're not well-versed in the details.

### Assumptions

Those executing these instructions must have basic-to-intermediate knowledge of the following:

* *nix command-line and utilities such as 'curl'
* *nix package installation
* AWS console navigation (there's a lot of it)
* AWS CLI (there's some of it)
* AWS services (CloudFormation, EC2, ECS, S3).
* It is especially important to have some understanding of the ECS service.  
  _It might be a good idea to run through an ECS tutorial before setting up this riglet._

### Dependencies

To complete these instructions successfully you'll need:

* AWS CLI (v1.11.57 minimum), and credentials working: `brew install awscli && aws configure`.
  * If you're going to configure a Slack Webhook and you're on AWS CLI 1.x, ensure this setting in your `~/.aws/config` file.

    ``` ini
    # ~/.aws/config
    [default]
    cli_follow_urlparam = false
    ```

* The `jq` utility, which is used often to interpret JSON responses from the AWS CLI: `brew install jq`.
* Ensure that you have your own private key pair setup on AWS - the name of the key will be used in the SSM parameter setup. See [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) for instructions.

### Creating a new Riglet

#### Setting up your `.make` file

This rig flavor uses `make` (yes, you read that right) to automate the creation of riglets.  Thus,
it is _super-important_ to get your `.make` file set up properly.  You can either do this via an
automated setup, or by doing some file manipulation.

##### Automated setup (recommended for first-timers)

1. Setup minimal `.make` for local settings interactively through `make .make`.
1. Confirm everything is valid with `make check-env`!
1. Continue below to fire up your riglet.

See [.make file Expert mode](#.make-file-expert-mode) for additional details.

#### Riglet Creation and Tear-down

There are a couple of scripts that automate the detailed steps covered further down.  They hide the
details, which is both a good and bad thing.

* `./create-standard-riglet.sh` to create a full riglet with standard environments (integration/staging/production).
  
  You will be asked some questions, the answers of which populate parameters in AWS' SSM Param Store. _Please take special note of the following_:
  * You will need a personal Github repo token.  Please see <http://tinyurl.com/yb5lxtr6>
  * There are special cases to take into account, so _pay close attention to the prompts_.  
    * KEY_NAME - EC2 SSH key name (your side of an AWS-generated key pair for the region you'll run in)
    * DOMAIN - Domain to use for Foundation (e.g. "buildit.tools")
    * DOMAIN_CERT - AWS Certification Manager GUID ("fea015e0-49a5-44b9-8c07-d78b1e942b85" is already created for buildit.tools in us-east-1 and is your best starting point)
    * (optional) EMAIL_ADDRESS - email address to which build notifications are sent.
      > If not included, no notifications are sent.  Be aware of this when issuing `make create-update` commands on existing stacks!
    * (optional) SLACK_WEBHOOK - a slack URL to which build notifications are sent.
      > If not included, no notifications are sent.  Be aware of this when issuing `make create-update` commands on existing stacks!
    * REPO_TOKEN - personal Github repo token (instructions above)
    * ECS_HOST_TYPE - the ECS hosting type (`EC2` or `FARGATE`)
    * DB_TYPE - the Database type (`aurora` or `couch` or `none`)
    * (required if DB_TYPE = aurora) DB_NAME - the Database name
    * (required if DB_TYPE = aurora) DB_HOST_TYPE - the hosting type (`provisioned` or `serverless`)
    * (required if DB_TYPE = aurora) DB_MASTER_PASSWORD - the master password (per environment)

* `make protect-riglet` to protect a running riglet (the Cfn stacks, anyway) from unintended deletion (`un-protect-riglet` to reverse.)
* `./delete-standard-riglet.sh` to delete it all.

See [Individual Makefile Targets](#building-using-individual-makefile-targets) if you want to build up a riglet by hand.

See [Manually Tearing Down a Riglet](#manually-tearing-down-a-riglet) if you want to tear down by hand.

#### Checking on things

* Watch things happen in the CloudFormation console and elsewhere in AWS, or ...
* Check the outputs of the activities above with `make outputs-foundation ENV=<environment>`
* Check the status of the activities above with `make status-foundation ENV=<environment>`

And ...

* Check AWS CloudWatch Logs for application logs.  In the Log Group Filter box search
  for for `<owner>-<application>` (at a minimum).  You can then drill down on the appropriate
  log group and individual log streams.
* Check that applications have successfully deployed - AWS -> CloudFormation -> Select your application or
  API stack, and view the URLs available under "Outputs", e.g. for the API application `https://OWNER-integration-APPLICAIONNAME.buildit.tools/v1/ping`
  where OWNER is the Owner name as specified in the .make file and APPLICATIONNAME is the REPO name as specified during app build creation (`make create-build REPO=...`).

---

## Additional Tech Details

### Environment specifics

For simplicity's sake, the templates don't currently allow a lot of flexibility in network CIDR ranges.
The assumption at this point is that these VPCs are self-contained and "sealed off" and thus don't need
to communicate with each other, thus no peering is needed and CIDR overlaps are fine.

Obviously, the templates can be updated if necessary.

| Environment    | CidrBlock      | Public Subnets (Multi AZ) | Private Subnets (Multi AZ) |
| :------------- | :------------- | :-------------            | :-------------             |
| integration    | 10.1.0.0/16    | 10.1.1.0/24,10.1.2.0/24   | 10.1.11.0/24,10.1.12.0/24  |
| staging        | 10.2.0.0/16    | 10.2.1.0/24,10.2.2.0/24   | 10.2.11.0/24,10.2.12.0/24  |
| production     | 10.3.0.0/16    | 10.3.1.0/24,10.3.2.0/24   | 10.3.11.0/24,10.3.12.0/24  |

### Database specifics

#### AWS RDS Aurora MySQL 5.6.x

| Environment    | DB URI (internal to VPC)                      | DB Subnets (Private, MultiAZ) |
| :------------- | :-------------                                | :-------------                |
| integration    | mysql://aurora.PROJECT.internal/DATABASE_NAME | 10.1.100.0/24,10.1.110.0/24   |
| staging        | mysql://aurora.PROJECT.internal/DATABASE_NAME | 10.2.100.0/24,10.2.110.0/24   |
| production     | mysql://aurora.PROJECT.internal/DATABASE_NAME | 10.3.100.0/24,10.3.110.0/24   |

#### CouchDB

| Environment    | DB URI (internal to VPC)             | DB Subnets (Private, SingleAZ) |
| :------------- | :-------------                       | :-------------                 |
| integration    | <http://couch.PROJECT.internal:5984> | 10.1.110.0/24                  |
| staging        | <http://couch.PROJECT.internal:5984> | 10.2.110.0/24                  |
| production     | <http://couch.PROJECT.internal:5984> | 10.3.110.0/24                  |

### Application specifics

| Application                 | ContainerPort  | ContainerMemory  | ListenerRulePriority | Subdomain
| :-------------              | :------------- | :--------------  | :-------------       | :--------
| APP REPO (e.g. bookit-api)  | (e.g. 8080)    | in MB (default: 512) | for ALB (e.g. 300)  | usually default to repo name (see create-standard-riglet.sh)

---

## Scaling

There are a few scaling "knobs" that can be twisted in running stacks, using CloudFormation console.
Conservative defaults are established in the templates, but the values can (and should) be updated
in specific running riglets later.

For example, production ECS should probably be scaled up, at least horizontally, if only for high availability,
so increasing the number of cluster instances to at least 2 (and arguably 4) is probably a good idea, as well
as running a number of ECS Tasks for each application.  ECS automatically distributes the Tasks
to the ECS cluster instances.

The same goes for the RDS Aurora instance.  We automatically create a replica for production (horizontal scaling).
To scale vertically, give it a larger box.  Note that a resize of the instance type should not result in any lost data.

The above changes can be made in the CloudFormation console.  To make changes find the appropriate stack,
select it, choose "update", and specify "use current template".  On the resulting parameters page make appropriate
changes and submit.

It's a good idea to always pause on the final submission page to see the predicted actions for your changes
before proceeding, or consider using a Change Set.

### Application Scaling Parameters

#### ECS (EC2 or Fargate)

| Parameter                    | Scaling Style | Stack                      | Parameter                    |
| :---                         | :---          | :---                       | :---                         |
| Number of Tasks              | Horizontal    | app (once created by build)| TaskDesiredCount             |
| Task CPU/Memory              | Vertical      | app (once created by build)| ContainerCpu/ContainerMemory |

#### ECS EC2

| Parameter                    | Scaling Style | Stack                      | Parameter                    |
| :---                         | :---          | :---                       | :---                         |
| # of ECS cluster instances   | Horizontal    | compute-ecs                | ClusterSize/ClusterMaxSize   |
| Size of ECS Hosts            | Vertical      | compute-ecs                | InstanceType                 |

### Database Scaling Parameters

And here are the available *database* scaling parameters.

#### Aurora RDS (provisioned)

| Parameter             | Scaling Style | Stack         | Parameter                                                                   |
| :---                  | :---          | :---          | :---                                                                        |
| Size of RDS Instances | Vertical      | db-aurora     | InstanceType                                                                |
| # of RDS Instances    | Horizontal    | db-aurora     | _currently via Replication property in Mappings inside db-aurora/main.yaml_ |

#### Aurora RDS (serverless)

| Parameter   | Scaling Style | Stack         | Parameter   |
| :---        | :---          | :---          | :---        |
| Minimum ACU | Vertical      | db-aurora     | MinCapacity |
| Maximum ACU | Vertical      | db-aurora     | MaxCapacity |

#### CouchDB scaling

The only scaling option is vertical:  give it a larger box.  Note that a resize of the instance type
does not result in any lost data.

| Parameter             | Scaling Style | Stack         | Parameter     |
| :---                  | :---          | :---          | :---          |
| Size of Couch Host    | Vertical      | db-couch      | InstanceType  |

---

## Troubleshooting

There are a number of strategies to troubleshoot issues.  In addition to monitoring and searching the AWS Console and Cloudwatch Logs, you can SSH into the VPC via a Bastion:

`make create-bastion ENV=<integration|staging|production>`

This will create a bastion that you can SSH into as well as open an inbound Security Group rule to allow your IP address in.  You can output the SSH command via:

`make outputs-bastion ENV=<integration|staging|production>`

Once inside the VPC, you can connect to any of the services you need.

Don't forget to tear down the Bastion when you are finished:
`make delete-bastion ENV=<integration|staging|production>`

---

## Maintenance

Except in very unlikely and unusual circumstances _all infrastructure/build changes should be made via CloudFormation
updates_ either by submitting template file changes via the appropriate make command, or by changing parameters in
the existing CloudFormation stacks using the console.  Failure to do so will cause the running environment(s) to diverge
from the as-declared CloudFormation resources and may (will) make it impossible to do updates in
the future via CloudFormation.

> An alternative to immediate execution of stack updates in the CloudFormation console is to use the "change set"
> feature. This creates a pending update to the CloudFormation stack that can be executed immediately, or go through an
> approval process.  This is a safe way to preview the "blast radius" of planned changes, too before committing.

### Updating ECS EC2 AMIs

The ECS EC2 cluster runs Amazon-supplied AMIs.  Occasionally, Amazon releases newer AMIs and marks existing instances as
out-of-date in the ECS console.  To update to the latest set of AMIs, update the ECSAMI parameter value in
`cloudformation/compute-ecs/ec2-hosts.yaml`.  We don't use the `recommended` version number as that could introduce
regressions without proper testing or notification of what has changed.

## Logs

We are using CloudWatch for centralized logging.  You can find the logs for each environment and application at [here](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logs:prefix=buildit)

Alarms are generated when ERROR level logs occur.  They get sent to the SLACK_WEBHOOK channel

---

## Appendix

---

### `.make` file Expert mode

The `.make` file can also be created by copying `.make.example` to `.make` and making changes
Example `.make` file with suggested values and comments (including optional values).

```ini
OWNER = <The owner of the stack>  (First initial + last name.)
PROFILE = <AWS Profile Name> ("default" if you don't have multiple profiles).
PROJECT = <Project Name> (e.g. "bookit")
REGION = <AWS Region> (Whatever region you intend to run within.  Some regions don't support all resource types, so the common ones are best)
```

### Building using Individual Makefile Targets

If you're not feeling particularly lucky, or you want to understand how things are assembled, or create a custom environment, or what-have-you, follow this guide.

#### Building it up

The full build pipeline requires at least integration, staging, and production environments, so the typical
installation is:

##### Execution/runtime Infrastructure and Environments

* Run `make create-deps`.  This creates additional parameters in AWS' SSM Param Store.  Please take special note of the following:
  * You will need a personal Github repo token.  Please see <http://tinyurl.com/yb5lxtr6>
  * There are special cases to take into account, so _pay close attention to the prompts_.
* Run `make create-environment ENV=integration` (runs `create-foundation`, `create-compute`, `create-db`)
* Run `make create-environment ENV=staging`
* Run `make create-environment ENV=production`

##### Build "Environments"

In this case there's no real "build environment", unless you want to consider AWS services an environment.
We are using CodePipeline and CodeBuild, which are build _managed services_ run by Amazon (think Jenkins in
the cloud, sort-of).  So what we're doing in this step is creating the build pipeline(s) for our code repo(s).

* Run `make create-build REPO=<repo_name> CONTAINER_PORT=<port> LISTENER_RULE_PRIORITY=<priority>`, same options for status: `make status-build` and outputs `make outputs-build`
  * REPO is the repo that hangs off buildit organization (e.g "bookit-api")
  * CONTAINER_PORT is the port that the application exposes (e.g. 8080)
  * LISTENER_RULE_PRIORITY is the priority of the the rule that gets created in the ALB.  While these won't ever conflict, ALB requires a unique number across all apps that share the ALB.  See [Application specifics](#application-specifics)
  * (optional) CONTAINER_MEMORY is the amount of memory (in MiB) to reserve for this application.  Defaults to 512.
  * (optional) HEALTH_CHECK_PATH is the path that is checked by the target group to determine health of the container.  Defaults to `'/'`
  * (optional) REPO_BRANCH is the branch name for the repo - MUST NOT CONTAIN SLASHES!
  * (optional) SUBDOMAIN is placed in front of the DOMAIN configured in the .make file when generating ALB listener rules.  Defaults to REPO.

##### Deployed Applications

It gets a little weird here.  You never start an application yourself in this riglet.  The build environments
actually dynamically create "app" stacks in CloudFormation as part of a successful build.  These app stacks
represent deployed and running code (they basically map to ECS Services and TaskDefinitions).

### Manually Tearing Down a Riglet

The easiest way to tear down a riglet is by running `./delete-standard-riglet.sh`.  
It will take a long time to execute, mostly because it deletes the riglet's S3 buckets.

To manually delete a running riglet, in order:

* Run `make delete-app ENV=<environment> REPO=<repo_name>` to delete any running App stacks.
  * if for some reason you deleted the pipeline first, you'll find you can't delete the app stacks because
    the role under which they were created was deleted with the pipeline. In this case you'll have to create
    a temporary "god role" and manually delete the app via the `aws cloudformation delete-stack` command,
    supplying the `--role-arn` override.
* Run `make delete-build REPO=<repo_name> REPO_BRANCH=<branch>` to delete the Pipline stack.
* Run `make delete-environment ENV=<environment>` to delete the Environment stack (runs `delete-db`, `delete-compute`, `delete-foundation`)
* Run `make delete-deps` to delete the required SSM parameters.
