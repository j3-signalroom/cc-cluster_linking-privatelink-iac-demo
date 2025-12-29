data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  cloud                           = "AWS"
  secrets_insert                  = "cluster_sharing"

  # Secrets Manager Paths
  confluent_secrets_path_prefix   = "/confluent_cloud_resource/${local.secrets_insert}"
}
