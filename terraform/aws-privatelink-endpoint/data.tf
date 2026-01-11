data "aws_vpc" "privatelink" {
  id = var.vpc_id_to_privatelink
}

# Find all private subnets
data "aws_subnets" "subnets_to_privatelink" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id_to_privatelink]
  }
  
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

# Get details for each subnet
data "aws_subnet" "subnets_to_privatelink" {
  for_each = toset(data.aws_subnets.subnets_to_privatelink.ids)
  id       = each.value
}

# Create a map of AZ with only showing the first subnet ID per AZ
locals {
  # Group subnets by AZ and take the first one from each AZ
  unique_az_subnets = {
    for az in distinct([
      for subnet_id in data.aws_subnets.subnets_to_privatelink.ids :
      data.aws_subnet.subnets_to_privatelink[subnet_id].availability_zone
    ]) : az => [
      for subnet_id in data.aws_subnets.subnets_to_privatelink.ids :
      subnet_id
      if data.aws_subnet.subnets_to_privatelink[subnet_id].availability_zone == az
    ][0]
  }
  
  # List of subnet IDs (one per unique AZ)
  selected_subnet_ids = values(local.unique_az_subnets)
}

# Get availability zone details for selected subnets
data "aws_availability_zone" "privatelink" {
  for_each = toset(local.selected_subnet_ids)
  name     = data.aws_subnet.subnets_to_privatelink[each.key].availability_zone
}
