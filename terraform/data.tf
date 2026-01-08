data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  cloud = "AWS"
}
