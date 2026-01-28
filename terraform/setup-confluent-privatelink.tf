# ===================================================================================
# SANDBOX VPC AND PRIVATELINK CONFIGURATION
# ===================================================================================
module "sandbox_vpc_privatelink" {
  source = "./modules/aws-vpc-confluent-privatelink"

  vpc_name          = "sandbox-${confluent_environment.non_prod.display_name}"
  vpc_cidr          = "10.0.0.0/20"
  subnet_count      = 3
  new_bits          = 4
  
  # Transit Gateway configuration
  tgw_id                   = var.tgw_id
  tgw_rt_id                = var.tgw_rt_id

  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ
  shared_phz_id            = aws_route53_zone.centralized_dns_vpc.zone_id

  depends_on = [ 
    confluent_environment.non_prod 
  ]
}

# ===================================================================================
# SHARED VPC AND PRIVATELINK CONFIGURATION
# ===================================================================================
module "shared_vpc_privatelink" {
  source = "./modules/aws-vpc-confluent-privatelink"

  vpc_name          = "shared-${confluent_environment.non_prod.display_name}"
  vpc_cidr          = "10.1.0.0/20"
  subnet_count      = 3
  new_bits          = 4
  
  # Transit Gateway configuration
  tgw_id                   = var.tgw_id
  tgw_rt_id                = var.tgw_rt_id

  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ
  shared_phz_id            = aws_route53_zone.centralized_dns_vpc.zone_id

  depends_on = [ 
    confluent_environment.non_prod
  ]
}

# ===================================================================================
# TFC AGENT AND VPN VPC ROUTES TO PRIVATELINK VPCS
# ===================================================================================
#
# Routes from TFC Agent VPC to Sandbox VPC
resource "aws_route" "tfc_agent_to_sandbox_privatelink" {
  for_each = toset(var.tfc_agent_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.sandbox_vpc_privatelink
  ]
}

# Routes from TFC Agent VPC to Shared VPC
resource "aws_route" "tfc_agent_to_shared_privatelink" {
  for_each = toset(var.tfc_agent_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.1.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.shared_vpc_privatelink
  ]
}

# Routes from VPN VPC to Sandbox VPC
resource "aws_route" "vpn_to_sandbox_privatelink" {
  for_each = toset(var.vpn_client_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.sandbox_vpc_privatelink
  ]
}

# Routes from VPN VPC to Shared VPC
resource "aws_route" "vpn_to_shared_privatelink" {
  for_each = toset(var.vpn_client_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.1.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.shared_vpc_privatelink
  ]
}

# ===================================================================================
# DNS RECORDS FOR SANDBOX AND SHARED VPC
# ===================================================================================
#
# Zonal records for Sandbox
resource "aws_route53_record" "sandbox_zonal" {
  for_each = module.sandbox_vpc_privatelink.vpc_subnet_details
  
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  name    = "*.${each.value.availability_zone_id}.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  
  records = [
    format("%s-%s%s",
      split(".", module.sandbox_vpc_privatelink.vpc_endpoint_dns)[0],
      each.value.availability_zone,
      replace(
        module.sandbox_vpc_privatelink.vpc_endpoint_dns,
        split(".", module.sandbox_vpc_privatelink.vpc_endpoint_dns)[0],
        ""
      )
    )
  ]
  
  depends_on = [module.sandbox_vpc_privatelink]
}

# Wildcard record for Sandbox
resource "aws_route53_record" "sandbox_wildcard" {
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  name    = "*.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [module.sandbox_vpc_privatelink.vpc_endpoint_dns]
  
  depends_on = [module.sandbox_vpc_privatelink]
}

# Zonal records for Shared
resource "aws_route53_record" "shared_zonal" {
  for_each = module.shared_vpc_privatelink.vpc_subnet_details
  
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  name    = "*.${each.value.availability_zone_id}.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  
  records = [
    format("%s-%s%s",
      split(".", module.shared_vpc_privatelink.vpc_endpoint_dns)[0],
      each.value.availability_zone,
      replace(
        module.shared_vpc_privatelink.vpc_endpoint_dns,
        split(".", module.shared_vpc_privatelink.vpc_endpoint_dns)[0],
        ""
      )
    )
  ]
  
  depends_on = [
    module.shared_vpc_privatelink
  ]
}

# Wildcard record for Shared
resource "aws_route53_record" "shared_wildcard" {
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  name    = "*.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [module.shared_vpc_privatelink.vpc_endpoint_dns]
  
  depends_on = [
    module.shared_vpc_privatelink
  ]
}

# ===================================================================================
# DNS CONFIGURATION - Manage existing PHZ and SYSTEM Resolver Rule
# ===================================================================================
resource "aws_route53_zone" "centralized_dns_vpc" {
  name = confluent_private_link_attachment.non_prod.dns_domain

  vpc {
    vpc_id = var.tfc_agent_vpc_id
  }

  tags = {
    Name      = "Centralized Confluent PrivateLink PHZ"
    Purpose   = "DNS for all Confluent clusters via PrivateLink"
    ManagedBy = "Terraform Cloud"
  }
}

# Associate the TFC Agent VPC PHZ with the Centralized DNS VPC PHZ
resource "aws_route53_zone_association" "confluent_to_dns_vpc" {
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  vpc_id  = var.dns_vpc_id

  depends_on = [ 
    aws_route53_zone.centralized_dns_vpc
  ]
}

resource "aws_route53_zone_association" "confluent_to_vpn_vpc" {
  zone_id = aws_route53_zone.centralized_dns_vpc.zone_id
  vpc_id  = var.vpn_vpc_id

  depends_on = [ 
    aws_route53_zone.centralized_dns_vpc
  ]
}

# ===================================================================================
# SYSTEM RESOLVER RULE
# ===================================================================================
resource "aws_route53_resolver_rule" "confluent_private_system" {
  domain_name = confluent_private_link_attachment.non_prod.dns_domain
  name        = "confluent-privatelink-phz-system"
  rule_type   = "SYSTEM"

  tags = {
    Name      = "Confluent PrivateLink PHZ System Rule"
    Purpose   = "Enable PHZ resolution for private Confluent clusters"
    ManagedBy = "Terraform Cloud"
  }
}

# ===================================================================================
# SYSTEM RESOLVER RULE VPC ASSOCIATIONS
# ===================================================================================
resource "aws_route53_resolver_rule_association" "confluent_private_dns_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_private_system.id
  vpc_id           = var.dns_vpc_id
  name             = "dns-vpc-confluent-private"
}

resource "aws_route53_resolver_rule_association" "confluent_private_vpn_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_private_system.id
  vpc_id           = var.vpn_vpc_id
  name             = "vpn-vpc-confluent-private"
}

resource "aws_route53_resolver_rule_association" "confluent_private_tfc_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_private_system.id
  vpc_id           = var.tfc_agent_vpc_id
  name             = "tfc-vpc-confluent-private"
}

resource "aws_route53_resolver_rule_association" "confluent_private_sandbox_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_private_system.id
  vpc_id           = module.sandbox_vpc_privatelink.vpc_id
  name             = "sandbox-vpc-confluent-private"
}

resource "aws_route53_resolver_rule_association" "confluent_private_shared_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.confluent_private_system.id
  vpc_id           = module.shared_vpc_privatelink.vpc_id
  name             = "shared-vpc-confluent-private"
}

# ===================================================================================
# WAIT FOR DNS PROPAGATION
# ===================================================================================
resource "time_sleep" "wait_for_dns" {
  depends_on = [
    aws_route53_record.sandbox_zonal,
    aws_route53_record.sandbox_wildcard,
    aws_route53_record.shared_zonal,
    aws_route53_record.shared_wildcard,
    aws_route.tfc_agent_to_sandbox_privatelink,
    aws_route.tfc_agent_to_shared_privatelink,
    aws_route.vpn_to_sandbox_privatelink,
    aws_route.vpn_to_shared_privatelink,
    aws_route53_zone.centralized_dns_vpc,
    aws_route53_resolver_rule.confluent_private_system,
    aws_route53_resolver_rule_association.confluent_private_dns_vpc,
    aws_route53_resolver_rule_association.confluent_private_vpn_vpc,
    aws_route53_resolver_rule_association.confluent_private_tfc_vpc,
    aws_route53_zone_association.confluent_to_dns_vpc,
    aws_route53_zone_association.confluent_to_vpn_vpc
  ]
  
  create_duration = "2m"
}
