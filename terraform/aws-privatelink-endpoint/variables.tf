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
