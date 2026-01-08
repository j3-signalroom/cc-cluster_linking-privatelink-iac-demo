data "aws_vpc" "privatelink" {
  id = var.vpc_id
}

data "aws_availability_zone" "privatelink" {
  for_each = var.subnets_to_privatelink
  zone_id = each.key
}

locals {
  network_id = split(".", var.dns_domain)[0]
}