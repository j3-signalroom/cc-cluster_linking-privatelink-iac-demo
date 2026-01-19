locals {
  network_id = split(".", var.dns_domain)[0]
}

# Get VPC details
data "aws_vpc" "privatelink" {
  id = var.vpc_id
}

# Get subnet details for each provided subnet
data "aws_subnet" "privatelink" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

# Get AZ info for each subnet
data "aws_availability_zone" "privatelink" {
  for_each = toset(var.subnet_ids)
  name     = data.aws_subnet.privatelink[each.key].availability_zone
}
