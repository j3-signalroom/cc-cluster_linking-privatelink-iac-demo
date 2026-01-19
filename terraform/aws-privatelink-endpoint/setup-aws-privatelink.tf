# Security Group for VPC Endpoint
resource "aws_security_group" "privatelink" {
  name        = "ccloud-privatelink_${local.network_id}_${var.vpc_id}"
  description = "Confluent Cloud Private Link security group for ${var.dns_domain}"
  vpc_id      = data.aws_vpc.privatelink.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
    description = "HTTP from VPC"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
    description = "HTTPS from VPC"
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
    description = "Kafka from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "ccloud-privatelink-${local.network_id}"
    VPC         = var.vpc_id
    Environment = "non-prod"
  }
}

# VPC Endpoint
resource "aws_vpc_endpoint" "privatelink" {
  vpc_id              = data.aws_vpc.privatelink.id
  service_name        = var.privatelink_service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink.id]
  private_dns_enabled = false
  
  subnet_ids = var.subnet_ids
  
  tags = {
    Name        = "ccloud-privatelink-${local.network_id}"
    VPC         = var.vpc_id
    Domain      = var.dns_domain
    Environment = "non-prod"
  }
}

# Route53 Private Hosted Zone
# CRITICAL: Zone name must exactly match Confluent DNS domain
resource "aws_route53_zone" "privatelink" {
  name = var.dns_domain
  
  # Associate with local VPC
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = {
    Name        = "phz-${local.network_id}-${var.vpc_id}"
    VPC         = var.vpc_id
    Domain      = var.dns_domain
    Environment = "non-prod"
  }
}

# Associate the Private Hosted Zone with the centralized DNS VPC
resource "aws_route53_zone_association" "dns_vpc" {
  zone_id = aws_route53_zone.privatelink.zone_id
  vpc_id  = var.enterprise_dns_vpc_id
}

# Global wildcard CNAME (for multi-AZ deployments)
resource "aws_route53_record" "privatelink_wildcard" {
  count = length(var.subnet_ids) > 1 ? 1 : 0
  
  zone_id = aws_route53_zone.privatelink.zone_id
  name    = "*.${var.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"]]
}

# Zonal CNAME records (one per subnet/AZ)
resource "aws_route53_record" "privatelink_zonal" {
  for_each = toset(var.subnet_ids)
  
  zone_id = aws_route53_zone.privatelink.zone_id
  name    = length(var.subnet_ids) == 1 ? "*.${var.dns_domain}" : "*.${data.aws_availability_zone.privatelink[each.key].zone_id}.${var.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  
  records = [
    format("%s-%s%s",
      split(".", aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"])[0],
      data.aws_availability_zone.privatelink[each.key].name,
      replace(
        aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"],
        split(".", aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"])[0],
        ""
      )
    )
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Wait for DNS propagation
resource "time_sleep" "wait_for_zone_associations" {
  depends_on = [
    aws_route53_zone_association.dns_vpc,
    aws_route53_record.privatelink_wildcard,
    aws_route53_record.privatelink_zonal
  ]
  
  create_duration = "30s"
}
