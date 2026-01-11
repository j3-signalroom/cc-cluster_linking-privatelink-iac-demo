# aws-privatelink-endpoint/variables.tf
# PRODUCTION VERSION - Manual Subnet IDs

variable "privatelink_service_name" {
  description = "AWS VPC Endpoint Service Name from Confluent Private Link Attachment"
  type        = string
}

variable "dns_domain" {
  description = "DNS domain from Confluent Private Link Attachment (e.g., us-east-1.aws.private.confluent.cloud). CRITICAL: Must be exact domain name."
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
  description = "List of subnet IDs for the VPC endpoint (one per AZ for high availability). Use private subnets in different availability zones."
  type        = list(string)
}

variable "tfc_agent_vpc_id" {
  description = "VPC ID where Terraform Cloud agent runs (for DNS resolution during terraform apply). Can be null if not using TFC agents."
  type        = string
  default     = null
  
  validation {
    condition     = var.tfc_agent_vpc_id == null || can(regex("^vpc-[a-f0-9]+$", var.tfc_agent_vpc_id))
    error_message = "TFC Agent VPC ID must be valid format (vpc-xxxxxxxxx) or null"
  }
}

variable "associate_with_tfc_agent_vpc" {
  description = <<-EOT
    Whether to create Route53 zone association with TFC agent VPC.
    
    IMPORTANT: Only ONE module per Confluent environment should set this to true.
    
    Recommended setup:
    - Sandbox module: associate_with_tfc_agent_vpc = true  (creates association)
    - Shared module:  associate_with_tfc_agent_vpc = false (skips duplicate)
    
    The TFC agent can resolve DNS for BOTH clusters through the single wildcard association.
  EOT
  type        = bool
  default     = false
}
