data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  cloud = "AWS"
}

locals {
  tfc_agent_vpc_rt_ids = length(trimspace(var.tfc_agent_vpc_rt_ids)) > 0 ? split(",", var.tfc_agent_vpc_rt_ids) : []
  vpn_client_vpc_rt_ids = length(trimspace(var.vpn_client_vpc_rt_ids)) > 0 ? split(",", var.vpn_client_vpc_rt_ids) : []
  acl_operations = ["READ", "WRITE", "DESCRIBE"]
}
