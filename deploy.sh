#!/bin/bash

#
# *** Script Syntax ***
# ./deploy.sh=<create | destroy> --profile=<SSO_PROFILE_NAME>
#                                --confluent-api-key=<CONFLUENT_API_KEY>
#                                --confluent-api-secret=<CONFLUENT_API_SECRET>
#                                [--day-count=<DAY_COUNT>]
#
#

set -euo pipefail  # Stop on error, undefined variables, and pipeline errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration folders
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

print_info "Terraform Directory: $TERRAFORM_DIR"

# Check required command (create or destroy) was supplied
case $1 in
  create)
    create_action=true;;
  destroy)
    create_action=false;;
  *)
    echo
    echo "(Error Message 001)  You did not specify one of the commands: create | destroy."
    echo
    echo "Usage:  Require all three arguments ---> `basename $0`=<create | destroy> --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
    ;;
esac

# Default optional variables
day_count=30

# Get the arguments passed by shift to remove the first word
# then iterate over the rest of the arguments
shift
for arg in "$@" # $@ sees arguments as separate words
do
    case $arg in
        *"--profile="*)
            AWS_PROFILE=$arg;;
        *"--confluent-api-key="*)
            arg_length=20
            confluent_api_key=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--confluent-api-secret="*)
            arg_length=23
            confluent_api_secret=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
        *"--day-count="*)
            arg_length=12
            day_count=${arg:$arg_length:$(expr ${#arg} - $arg_length)};;
    esac
done

# Check required --profile argument was supplied
if [ -z $AWS_PROFILE ]
then
    echo
    echo "(Error Message 002)  You did not include the proper use of the -- profile=<SSO_PROFILE_NAME> argument in the call."
    echo
    echo "Usage:  Require all three arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-key argument was supplied
if [ -z $confluent_api_key ]
then
    echo
    echo "(Error Message 003)  You did not include the proper use of the --confluent-api-key=<CONFLUENT_API_KEY> argument in the call."
    echo
    echo "Usage:  Require all three arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-secret argument was supplied
if [ -z $confluent_api_secret ]
then
    echo
    echo "(Error Message 004)  You did not include the proper use of the --confluent-api-secret=<CONFLUENT_API_SECRET> argument in the call."
    echo
    echo "Usage:  Require all three arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Get the AWS SSO credential variables that are used by the AWS CLI commands to authenicate
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get region $AWS_PROFILE)

# Function to check if Terraform is initialized
check_terraform_init() {
    if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
        return 1
    fi
    return 0
}

# Confluent Root Path
confluent_secret_root_path=/confluent_cloud_resource/cc_cluster_linking_demo

# Function to deploy infrastructure
deploy_infrastructure() {
    print_step "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Export AWS credentials, Confluent credentials and optional variables as environment variables
    export TF_VAR_aws_region="${AWS_REGION}"
    export TF_VAR_aws_access_key_id="${AWS_ACCESS_KEY_ID}"
    export TF_VAR_aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}"
    export TF_VAR_aws_session_token="${AWS_SESSION_TOKEN}"
    export TF_VAR_confluent_api_key="${confluent_api_key}"
    export TF_VAR_confluent_api_secret="${confluent_api_secret}"
    export TF_VAR_confluent_secret_root_path="${confluent_secret_root_path}"
    export TF_VAR_day_count="${day_count}"

    # Initialize Terraform if needed
    if ! check_terraform_init; then
        print_info "Initializing Terraform..."
        terraform init
    fi
    
    # Plan
    print_info "Running Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    read -p "Do you want to apply this plan? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Applying Terraform plan..."
        terraform apply tfplan
        rm tfplan
        print_info "Infrastructure deployed successfully!"
        cd ..
        return 0
    else
        print_warn "Deployment cancelled"
        rm tfplan
        return 1
    fi
}

# Function to undeploy infrastructure
undeploy_infrastructure() {
    print_step "Destroying infrastructure with Terraform..."

    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if ! check_terraform_init; then
        print_info "Initializing Terraform..."
        terraform init
    fi
    
    # Export AWS credentials, Confluent credentials and optional variables as environment variables
    export TF_VAR_aws_region="${AWS_REGION}"
    export TF_VAR_aws_access_key_id="${AWS_ACCESS_KEY_ID}"
    export TF_VAR_aws_secret_access_key="${AWS_SECRET_ACCESS_KEY}"
    export TF_VAR_aws_session_token="${AWS_SESSION_TOKEN}"
    export TF_VAR_confluent_api_key="${confluent_api_key}"
    export TF_VAR_confluent_api_secret="${confluent_api_secret}"
    export TF_VAR_confluent_secret_root_path="${confluent_secret_root_path}"

    # Destroy
    print_info "Running Terraform destroy..."
    terraform destroy -auto-approve

    # Force the delete of the AWS Secrets
    print_info "Deleting AWS Secrets..."
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/schema_registry_cluster --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_manager/java_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_consumer/java_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_producer/java_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_manager/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_consumer/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_producer/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/destination_cluster/app_manager/java_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/destination_cluster/app_consumer/java_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/destination_cluster/app_manager/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/destination_cluster/app_consumer/python_client --force-delete-without-recovery || true
    
    print_info "Infrastructure destroyed successfully!"
    cd ..
}   

# Main execution flow
if [ "$create_action" = true ]
then
    deploy_infrastructure
else
    undeploy_infrastructure
    exit 0
fi
