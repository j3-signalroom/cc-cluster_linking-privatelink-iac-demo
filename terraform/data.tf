data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_subnet" "tfc_agent" {
  id = var.tfc_agent_subnet_id
}

locals {
  cloud = "AWS"
}
