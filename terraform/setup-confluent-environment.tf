resource "confluent_environment" "non_prod" {
  display_name = "non-prod"

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_network" "non_prod" {
  display_name     = "AWS Private Link Network"
  cloud            = local.cloud
  region           = var.aws_region
  connection_types = ["PRIVATELINK"]

  # Use combined zones from both VPCs
  zones = local.all_zone_ids
  
  environment {
    id = confluent_environment.non_prod.id
  }
}