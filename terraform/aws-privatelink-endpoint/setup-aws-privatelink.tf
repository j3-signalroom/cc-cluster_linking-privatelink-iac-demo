locals {
  network_id = split(".", var.dns_domain)[0]
}

resource "aws_security_group" "privatelink" {
  name = "ccloud-privatelink_${local.network_id}_${var.vpc_id_to_privatelink}"
  description = "Confluent Cloud Private Link minimal security group for ${var.dns_domain} in ${var.vpc_id_to_privatelink}"
  vpc_id = data.aws_vpc.privatelink.id

  ingress {
    # Optional HTTP→HTTPS redirects
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block] # Restricted to VPC CIDR block only
  }

  ingress {
    # REST APIs (Schema Registry, Connect, ksqlDB, Cluster Linking)
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block] # Restricted to VPC CIDR block only
  }

  ingress {
    # Kafka broker connections
    from_port = 9092
    to_port = 9092
    protocol = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block] # Restricted to VPC CIDR block only
  }

  lifecycle {
    # For zero-downtime updates
    create_before_destroy = true
  }
}

# Creates one ENI per subnet for zone-aware routing, which is critical for Confluent Cloud's multi-AZ broker placement
resource "aws_vpc_endpoint" "privatelink" {
  vpc_id = data.aws_vpc.privatelink.id
  service_name = var.privatelink_service_name
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.privatelink.id,
  ]

  subnet_ids = [for zone, subnet_id in data.aws_subnets.subnets_to_privatelink.ids: subnet_id]
  private_dns_enabled = false
}

# This zone overrides public DNS for all *.dns_domain lookups within associated VPCs
resource "aws_route53_zone" "privatelink" {
  name = var.dns_domain

  vpc {
    vpc_id = data.aws_vpc.privatelink.id
  }
}

# Creates wildcard CNAME record for multi-AZ PrivateLink endpoints
resource "aws_route53_record" "privatelink" {
  count = length(data.aws_subnets.subnets_to_privatelink.ids) == 1 ? 0 : 1
  
  depends_on = [aws_vpc_endpoint.privatelink]
  
  zone_id = aws_route53_zone.privatelink.zone_id
  name = "*.${aws_route53_zone.privatelink.name}"
  type = "CNAME"
  ttl  = "60"
  records = [
    try(aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"], "")
  ]
  
  lifecycle {
    ignore_changes = [records]
  }
}

# Creates wildcard CNAME records per AZ for multi-AZ PrivateLink endpoints
resource "aws_route53_record" "privatelink-zonal" {
  for_each = toset(data.aws_subnets.subnets_to_privatelink.ids)
  
  depends_on = [aws_vpc_endpoint.privatelink]

  zone_id = aws_route53_zone.privatelink.zone_id
  name = length(data.aws_subnets.subnets_to_privatelink.ids) == 1 ? "*" : "*.${data.aws_availability_zone.privatelink[each.key].zone_id}"
  type = "CNAME"
  ttl  = "60"
  records = [
    format("%s-%s%s",
      try(split(".", aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"])[0], "vpce-temp"),
      data.aws_availability_zone.privatelink[each.key].name,
      try(replace(
        aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"], 
        split(".", aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"])[0], 
        ""
      ), ".vpce-svc-temp.us-east-1.vpce.amazonaws.com")
    )
  ]
  
  lifecycle {
    ignore_changes = [records]
  }
}

# Associate VPC associated with privatelink Route 53 Private Hosted Zone with TFC Agent VPC
resource "aws_route53_zone_association" "privatelink_to_vpc_to_agent" {
  zone_id = aws_route53_zone.privatelink.zone_id
  vpc_id  = var.tfc_agent_vpc_id
}

# Wait for DNS association to propagate
resource "time_sleep" "wait_for_zone_associations" {
  depends_on = [
    aws_route53_zone_association.privatelink_to_vpc_to_agent
  ]

  create_duration = "2m"
}