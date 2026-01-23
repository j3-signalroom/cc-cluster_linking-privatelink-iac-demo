variable "privatelink_service_name" {
  description = "AWS VPC Endpoint Service Name from Confluent Private Link Attachment"
  type        = string
}

variable "dns_domain" {
  description = "DNS domain from Confluent Private Link Attachment (e.g., us-east-1.aws.private.confluent.cloud)"
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

variable "tgw_id" {
  description = "Transit Gateway ID to attach the PrivateLink VPC to"
  type        = string
} 

variable "tgw_rt_id" {
  description = "Transit Gateway Route Table ID to associate the PrivateLink VPC attachment with"
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

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "vpc_rt_id" {
  description = "VPC Route Table ID"
  type        = string
}

variable "vpc_subnet_details" {
  description = "Map of AZ names to subnet IDs for the VPC endpoint"
  type        = map(object({
    id                   = string
    cidr_block           = string
    availability_zone    = string
    availability_zone_id = string
    name                 = string
  }))
}

variable "vpn_client_cidr" {
  description = "VPN Client CIDR"
  type        = string
}

variable "tfc_agent_vpc_id" {
  description = "Terraform Cloud Agent VPC ID (for tagging PHZ association purposes)"
  type        = string
}

variable "tfc_agent_vpc_cidr" {
  description = "Terraform Cloud Agent VPC CIDR"
  type        = string
}

variable "shared_phz_id" {
  description = "Optional: Existing Route53 Private Hosted Zone ID. If provided, the module will use this instead of creating a new one. Leave empty to create a new PHZ."
  type        = string
}