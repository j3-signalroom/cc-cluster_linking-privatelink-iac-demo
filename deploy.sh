#!/bin/bash

#
# *** Script Syntax ***
# ./deploy.sh=<create | delete> --profile=<SSO_PROFILE_NAME>
#                               --confluent-api-key=<CONFLUENT_API_KEY>
#                               --confluent-api-secret=<CONFLUENT_API_SECRET>
#                               [--day-count=<DAY_COUNT>]
#
#

# Check required command (create or delete) was supplied
case $1 in
  create)
    create_action=true;;
  delete)
    create_action=false;;
  *)
    echo
    echo "(Error Message 001)  You did not specify one of the commands: create | delete."
    echo
    echo "Usage:  Require all five arguments ---> `basename $0`=<create | delete> --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET> --snowflake-warehouse=<SNOWFLAKE_WAREHOUSE> --admin-service-user-secrets-root-path=<ADMIN_SERVICE_USER_SECRETS_ROOT_PATH>"
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
    echo "Usage:  Require all five arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-key argument was supplied
if [ -z $confluent_api_key ]
then
    echo
    echo "(Error Message 003)  You did not include the proper use of the --confluent-api-key=<CONFLUENT_API_KEY> argument in the call."
    echo
    echo "Usage:  Require all five arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check required --confluent-api-secret argument was supplied
if [ -z $confluent_api_secret ]
then
    echo
    echo "(Error Message 004)  You did not include the proper use of the --confluent-api-secret=<CONFLUENT_API_SECRET> argument in the call."
    echo
    echo "Usage:  Require all five arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Check --day-count argument was supplied
if [ -z $day_count ] && [ "$create_action" = true ]
then
    echo
    echo "(Error Message 005)  You did not include the proper use of the --day-count=<DAY_COUNT> argument in the call."
    echo
    echo "Usage:  Require all five arguments ---> `basename $0 $1` --profile=<SSO_PROFILE_NAME> --confluent-api-key=<CONFLUENT_API_KEY> --confluent-api-secret=<CONFLUENT_API_SECRET>"
    echo
    exit 85 # Common GNU/Linux Exit Code for 'Interrupted system call should be restarted'
fi

# Get the AWS SSO credential variables that are used by the AWS CLI commands to authenicate
aws sso login $AWS_PROFILE
eval $(aws2-wrap $AWS_PROFILE --export)
export AWS_REGION=$(aws configure get region $AWS_PROFILE)

# Confluent Root Path
confluent_secret_root_path=/confluent_cloud_resource/cc_cluster_linking_demo

# Create terraform.tfvars file
if [ "$create_action" = true ]
then
    printf "aws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nconfluent_api_key=\"${confluent_api_key}\"\
    \nconfluent_api_secret=\"${confluent_api_secret}\"\
    \nconfluent_secret_root_path=\"${confluent_secret_root_path}\"\
    \nday_count=${day_count}" > terraform.tfvars
else
    printf "aws_region=\"${AWS_REGION}\"\
    \naws_access_key_id=\"${AWS_ACCESS_KEY_ID}\"\
    \naws_secret_access_key=\"${AWS_SECRET_ACCESS_KEY}\"\
    \naws_session_token=\"${AWS_SESSION_TOKEN}\"\
    \nconfluent_api_key=\"${confluent_api_key}\"\
    \nconfluent_api_secret=\"${confluent_api_secret}\"\
    \nconfluent_secret_root_path=\"${confluent_secret_root_path}\"" > terraform.tfvars
fi

# Initialize the Terraform configuration
terraform init

if [ "$create_action" = true ]
then
    # Create/Update the Terraform configuration
    terraform init
    terraform plan -var-file=terraform.tfvars

    # Apply the Terraform configuration
    terraform apply -var-file=terraform.tfvars
else
    # Destroy the Terraform configuration
    terraform destroy -var-file=terraform.tfvars

    # Force the delete of the AWS Secrets
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/schema_registry_cluster/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_manager/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_consumer/python_client --force-delete-without-recovery || true
    aws secretsmanager delete-secret --secret-id ${confluent_secret_root_path}/source_cluster/app_producer/python_client --force-delete-without-recovery || true
fi