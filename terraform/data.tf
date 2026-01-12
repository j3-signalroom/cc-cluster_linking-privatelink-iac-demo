data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  cloud = "AWS"
}

# Get zones from BOTH sets of subnets
data "aws_subnet" "sandbox_subnets" {
  for_each = toset(split(",", var.sandbox_cluster_subnet_ids))
  id       = each.value
}

data "aws_subnet" "shared_subnets" {
  for_each = toset(split(",", var.shared_cluster_subnet_ids))
  id       = each.value
}

locals {
  # Combine zone IDs from both VPCs
  all_zone_ids = distinct(concat(
    [for s in data.aws_subnet.sandbox_subnets : s.availability_zone_id],
    [for s in data.aws_subnet.shared_subnets : s.availability_zone_id]
  ))

  acl_operations = ["READ", "WRITE", "DESCRIBE"]
}
