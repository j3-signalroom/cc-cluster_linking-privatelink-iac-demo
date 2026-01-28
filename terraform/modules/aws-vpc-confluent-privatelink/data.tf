data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  available_zones = slice(data.aws_availability_zones.available.names, 0, var.subnet_count)
}

# Get Confluent Environment details
data "confluent_environment" "privatelink" {
  id = var.confluent_environment_id
}

locals {
  # Extract network ID from DNS domain
  network_id = split(".", var.dns_domain)[0]
}
