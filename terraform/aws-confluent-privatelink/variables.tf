variable "privatelink_service_name" {
  description = "AWS VPC Endpoint Service Name from Confluent Private Link Attachment"
  type        = string
}

variable "dns_domain" {
  description = "DNS domain from Confluent Private Link Attachment (e.g., us-east-1.aws.private.confluent.cloud)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the VPC endpoint will be created"
  type        = string
  
  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "VPC ID must be valid format (vpc-xxxxxxxxx)"
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the VPC endpoint (one per AZ for high availability)"
  type        = list(string)
}

variable "dns_vpc_id" {
  description = "Enterprise (centralized) DNS VPC ID - Private Hosted Zones will be associated with this VPC"
  type        = string
}

variable "confluent_environment_id" {
  description = "Confluent Environment ID"
  type        = string
}

variable "confluent_platt_id" {
  description = "Confluent PrivateLink Attachment ID"
  type        = string
}

variable "tfc_agent_vpc_id" {
  description = "Terraform Cloud Agent VPC ID (for tagging PHZ association purposes)"
  type        = string
}