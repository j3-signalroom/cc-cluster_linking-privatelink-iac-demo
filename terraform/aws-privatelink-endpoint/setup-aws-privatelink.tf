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
}

# Wait for DNS propagation
resource "time_sleep" "wait_for_zone_associations" {
  depends_on = [
    aws_route53_zone_association.privatelink_to_tfc_agent,
    aws_route53_record.privatelink_wildcard,
    aws_route53_record.privatelink_zonal
  ]
  
  create_duration = "2m"
}

# Security Group for Inbound Resolver (in Confluent VPC)
resource "aws_security_group" "inbound_resolver" {
  name_prefix = "confluent-inbound-resolver-"
  description = "Security group for Route 53 Inbound Resolver"
  vpc_id      = data.aws_vpc.privatelink.id

  ingress {
    description = "DNS TCP from Client VPN VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.client_vpn.cidr_block]
  }

  ingress {
    description = "DNS UDP from Client VPN VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.client_vpn.cidr_block]
  }

  ingress {
    description = "DNS TCP from Client VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  ingress {
    description = "DNS UDP from Client VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "confluent-inbound-resolver-sg"
    ManagedBy   = "Terraform"
  }
}

# Security Group for Outbound Resolver (in Client VPN VPC)
resource "aws_security_group" "outbound_resolver" {
  name_prefix = "client-vpn-outbound-resolver-"
  description = "Security group for Route 53 Outbound Resolver"
  vpc_id      = data.aws_vpc.client_vpn.id

  ingress {
    description = "DNS TCP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.client_vpn.cidr_block]
  }

  ingress {
    description = "DNS UDP from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.client_vpn.cidr_block]
  }

  ingress {
    description = "DNS TCP from Client VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  ingress {
    description = "DNS UDP from Client VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "client-vpn-outbound-resolver-sg"
    ManagedBy   = "Terraform"
  }
}

# Route 53 Resolver - Inbound Endpoint (in Confluent VPC)
resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "confluent-inbound-resolver"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.inbound_resolver.id]

  # Use first two subnets in different AZs
  ip_address {
    subnet_id = var.client_vpn_subnet_ids[0]
  }

  ip_address {
    subnet_id = var.client_vpn_subnet_ids[1]
  }

  tags = {
    Name        = "confluent-inbound-resolver"
    ManagedBy   = "Terraform"
  }
}

# Route 53 Resolver - Outbound Endpoint (in Client VPN VPC)
resource "aws_route53_resolver_endpoint" "outbound" {
  name      = "client-vpn-outbound-resolver"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.outbound_resolver.id]

  # Use first two subnets in different AZs
  ip_address {
    subnet_id = var.client_vpn_subnet_ids[0]
  }

  ip_address {
    subnet_id = var.client_vpn_subnet_ids[1]
  }

  tags = {
    Name        = "client-vpn-outbound-resolver"
    ManagedBy   = "Terraform"
  }
}

# Route 53 Resolver Rule - Forward *.<AWS_REGION>.aws.private.confluent.cloud to Inbound Endpoint
resource "aws_route53_resolver_rule" "confluent_cloud" {
  name                 = "confluent-cloud-resolver-rule"
  domain_name          = var.dns_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  # Target the inbound resolver IPs
  dynamic "target_ip" {
    for_each = aws_route53_resolver_endpoint.inbound.ip_address
    content {
      ip = target_ip.value.ip
    }
  }

  tags = {
    Name        = "confluent-cloud-resolver-rule"
    ManagedBy   = "Terraform"
  }
}

# Associate the resolver rule with Client VPN VPC
resource "aws_route53_resolver_rule_association" "client_vpn" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_cloud.id
  vpc_id           = data.aws_vpc.client_vpn.id
}