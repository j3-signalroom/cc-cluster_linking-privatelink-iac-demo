locals {
  network_id = split(".", var.dns_domain)[0]
}

resource "aws_security_group" "privatelink" {
  name        = "ccloud-privatelink_${local.network_id}_${var.vpc_id_to_privatelink}"
  description = "Confluent Cloud Private Link minimal security group for ${var.dns_domain} in ${var.vpc_id_to_privatelink}"
  vpc_id      = data.aws_vpc.privatelink.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "privatelink" {
  vpc_id              = data.aws_vpc.privatelink.id
  service_name        = var.privatelink_service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink.id]
  private_dns_enabled = false
  
  # Use selected subnet IDs (one per unique AZ)
  subnet_ids = local.selected_subnet_ids
}

resource "aws_route53_zone" "privatelink" {
  name = var.dns_domain

  vpc {
    vpc_id = data.aws_vpc.privatelink.id
  }
}

# Global wildcard CNAME (only for multi-AZ deployments)
resource "aws_route53_record" "privatelink" {
  count = length(local.selected_subnet_ids) > 1 ? 1 : 0
  
  zone_id = aws_route53_zone.privatelink.zone_id
  name    = "*.${aws_route53_zone.privatelink.name}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"]]
}

# Zonal CNAME records (one per selected subnet/AZ)
resource "aws_route53_record" "privatelink-zonal" {
  for_each = toset(local.selected_subnet_ids)
  
  zone_id = aws_route53_zone.privatelink.zone_id
  name    = length(local.selected_subnet_ids) == 1 ? "*" : "*.${data.aws_availability_zone.privatelink[each.key].zone_id}"
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
}

resource "aws_route53_zone_association" "privatelink_to_vpc_to_agent" {
  zone_id = aws_route53_zone.privatelink.zone_id
  vpc_id  = var.tfc_agent_vpc_id
}

resource "time_sleep" "wait_for_zone_associations" {
  depends_on      = [aws_route53_zone_association.privatelink_to_vpc_to_agent]
  create_duration = "2m"
}
