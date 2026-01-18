# ===================================================
# CONFLUENT CLOUD CONFIGURATION
# ===================================================
variable "confluent_api_key" {
  description = "Confluent API Key (also referred as Cloud API ID)."
  type        = string
}

variable "confluent_api_secret" {
  description = "Confluent API Secret."
  type        = string
  sensitive   = true
}

# ===================================================
# AWS PROVIDER CONFIGURATION
# ===================================================
variable "aws_region" {
    description = "The AWS Region."
    type        = string
}

variable "aws_access_key_id" {
    description = "The AWS Access Key ID."
    type        = string
    default     = ""
}

variable "aws_secret_access_key" {
    description = "The AWS Secret Access Key."
    type        = string
    default     = ""
}

variable "aws_session_token" {
    description = "The AWS Session Token."
    type        = string
    default     = ""
}

# ===================================================
# CONFLUENT API KEY ROTATION CONFIGURATION
# ===================================================
variable "day_count" {
    description = "How many day(s) should the API Key be rotated for."
    type        = number
    default     = 30
    
    validation {
        condition     = var.day_count >= 1
        error_message = "Rolling day count, `day_count`, must be greater than or equal to 1."
    }
}

variable "number_of_api_keys_to_retain" {
    description = "Specifies the number of API keys to create and retain.  Must be greater than or equal to 2 in order to maintain proper key rotation for your application(s)."
    type        = number
    default     = 2
    
    validation {
        condition     = var.number_of_api_keys_to_retain >= 2
        error_message = "Number of API keys to retain, `number_of_api_keys_to_retain`, must be greater than or equal to 2."
    }
}

variable "confluent_secret_root_path" {
    description = "The root path in AWS Secrets Manager to store the Confluent Cloud Resource API keys."
    type        = string
}

# ===================================================
# VPC CONFIGURATIONS
# ===================================================
variable "sandbox_cluster_vpc_id" {
  description = "The VPC ID used for the PrivateLink endpoint for the Sandbox Kafka Cluster."
  type        = string
}

variable "sandbox_cluster_subnet_ids" {
  description = "The Subnet IDs used for the PrivateLink endpoint for the Sandbox Kafka Cluster."
  type        = string
}

variable "shared_cluster_vpc_id" {
  description = "The VPC ID used for the PrivateLink endpoint for the Shared Kafka Cluster."
  type        = string
}

variable "shared_cluster_subnet_ids" {
  description = "The Subnet IDs used for the PrivateLink endpoint for the Shared Kafka Cluster."
  type        = string
}

# ===================================================
# TERRAFORM CLOUD AGENT CONFIGURATION
# ===================================================
variable "tfc_agent_vpc_id" {
  description = "VPC ID where the Terraform Cloud Agent is running."
  type        = string
}

variable "tfc_agent_subnet_ids" {
  description = "Subnet IDs for TFC Agent VPC PrivateLink endpoint (comma-separated)"
  type        = string
}

variable "tfe_token" {
  description = "Terraform Cloud API Token"
  type        = string
#  sensitive   = true
  default     = ""
}

