# VPC Endpoint
resource "aws_vpc_endpoint" "privatelink" {
  vpc_id              = var.vpc_id
  service_name        = var.privatelink_service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.privatelink.id]
  private_dns_enabled = false
  
  subnet_ids = [for subnet in var.vpc_subnet_details : subnet.id]
  
  tags = {
    Name        = "ccloud-privatelink-${local.network_id}"
    VPC         = var.vpc_id
    Domain      = var.dns_domain
    Environment = data.confluent_environment.privatelink.display_name
  }

  depends_on = [ 
    aws_security_group.privatelink 
  ]
}

# ============================================================================
# ROUTE53 PRIVATE HOSTED ZONE AND RECORDS
# ============================================================================

resource "aws_route53_zone" "privatelink" {
  count = var.shared_phz_id == "" ? 1 : 0
  
  name = var.dns_domain
  
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = {
    Name        = "phz-${local.network_id}-${var.vpc_id}"
    VPC         = var.vpc_id
    Domain      = var.dns_domain
    Environment = data.confluent_environment.privatelink.display_name
  }
}

# Data source for existing PHZ (when shared_phz_id is provided)
data "aws_route53_zone" "existing" {
  count   = var.shared_phz_id != "" ? 1 : 0
  zone_id = var.shared_phz_id
}

locals {
  shared_phz_id = var.shared_phz_id != "" ? var.shared_phz_id : aws_route53_zone.privatelink[0].zone_id  
}

# ============================================================================
# VPC ASSOCIATIONS
# ============================================================================
#
# Associate the PHZ with the local VPC (only if using existing PHZ AND not TFC agent VPC)
resource "aws_route53_zone_association" "local_vpc" {
  count = (
    var.shared_phz_id != "" && 
    var.vpc_id != var.tfc_agent_vpc_id &&
    var.vpc_id != var.dns_vpc_id
  ) ? 1 : 0
  
  zone_id = local.shared_phz_id
  vpc_id  = var.vpc_id
}

# Associate the PHZ with the DNS VPC, if provided
resource "aws_route53_zone_association" "dns_vpc" {
  count = (var.dns_vpc_id != "") ? 1 : 0

  zone_id = local.shared_phz_id
  vpc_id  = var.dns_vpc_id

  depends_on = [ 
    aws_route53_zone.privatelink,
    aws_route53_zone_association.local_vpc
  ]
}

# Wait for DNS propagation
resource "time_sleep" "wait_for_zone_associations" {
  depends_on = [
    aws_route53_zone_association.dns_vpc
  ]
  
  create_duration = "3m"
}

resource "confluent_private_link_attachment_connection" "privatelink" {
  display_name = "ccloud-plattc-${local.network_id}"
  
  environment {
    id = var.confluent_environment_id
  }
  
  aws {
    vpc_endpoint_id = aws_vpc_endpoint.privatelink.id
  }

  private_link_attachment {
    id = var.confluent_platt_id
  }
  
  depends_on = [
    time_sleep.wait_for_zone_associations
  ]
}

# ============================================================================
# TRANSIT GATEWAY ATTACHMENT
# ============================================================================
resource "aws_ec2_transit_gateway_vpc_attachment" "privatelink" {
  subnet_ids         = [for subnet in var.vpc_subnet_details : subnet.id]
  transit_gateway_id = var.tgw_id
  vpc_id             = var.vpc_id
  
  # Enable DNS support for cross-VPC resolution
  dns_support = "enable"

  tags = {
    Name        = "${var.vpc_id}-ccloud-privatelink-tgw-attachment"
    Environment = data.confluent_environment.privatelink.display_name
    ManagedBy   = "Terraform Cloud"
    Purpose     = "Confluent PrivateLink connectivity"
  }
}

# Associate with Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table_association" "privatelink" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.privatelink.id
  transit_gateway_route_table_id = var.tgw_rt_id
}

# ============================================================================
# ROUTE TABLE UPDATES FOR TRANSIT GATEWAY CONNECTIVITY
# ============================================================================
#
# Add route to TFC Agent VPC via Transit Gateway
resource "aws_route" "privatelink_to_tfc_agent" {
  count = var.tfc_agent_vpc_cidr != "" ? 1 : 0
  
  route_table_id         = var.vpc_rt_id
  destination_cidr_block = var.tfc_agent_vpc_cidr
  transit_gateway_id     = var.tgw_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.privatelink
  ]
}

# Add route to VPN clients via Transit Gateway
resource "aws_route" "privatelink_to_vpn_client" {
  count = var.vpn_client_cidr != "" ? 1 : 0
  
  route_table_id         = var.vpc_rt_id
  destination_cidr_block = var.vpn_client_cidr
  transit_gateway_id     = var.tgw_id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.privatelink
  ]
}

# ============================================================================
# SECURITY GROUP RULES FOR THE VPC
# ============================================================================
resource "aws_security_group" "privatelink" {
  name        = "ccloud-privatelink_${local.network_id}_${var.vpc_id}"
  description = "Confluent Cloud Private Link Security Group for ${var.dns_domain}"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "ccloud-privatelink-${local.network_id}"
    VPC         = var.vpc_id
    Environment = data.confluent_environment.privatelink.display_name
  }
}

resource "aws_security_group_rule" "allow_https" {
  description       = "HTTPS from VPC, TFC Agent VPCs, and VPN clients"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.tfc_agent_vpc_cidr, var.vpn_client_cidr, var.vpc_cidr]
  security_group_id = aws_security_group.privatelink.id
}

resource "aws_security_group_rule" "allow_kafka" {
  description       = "Kafka from VPC, TFC Agent VPCs, and VPN clients"
  type              = "ingress"
  from_port         = 9092
  to_port           = 9092
  protocol          = "tcp"
  cidr_blocks       = [var.tfc_agent_vpc_cidr, var.vpn_client_cidr, var.vpc_cidr]
  security_group_id = aws_security_group.privatelink.id
}
