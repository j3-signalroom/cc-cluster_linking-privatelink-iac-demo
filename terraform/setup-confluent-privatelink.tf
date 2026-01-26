# ===================================================================================
# SANDBOX AWS VPC WITH TGW INTEGRATION CREATION
# ===================================================================================
module "sandbox_vpc" {
  source = "./modules/aws-vpc"
  
  vpc_name          = "sandbox-${confluent_environment.sandbox.display_name}"
  vpc_cidr          = "10.0.0.0/20"
  subnet_count      = 3
  new_bits          = 4

  depends_on = [ 
    confluent_private_link_attachment.sandbox 
  ]
}

# ===================================================================================
# SHARED (CLUSTER) AWS VPC WITH TGW INTEGRATION CREATION
# ===================================================================================
module "shared_vpc" {
  source = "./modules/aws-vpc"
  
  vpc_name          = "shared-${confluent_environment.shared.display_name}"
  vpc_cidr          = "10.1.0.0/20"
  subnet_count      = 3
  new_bits          = 4

  depends_on = [ 
    confluent_private_link_attachment.shared
  ]
}

# ===================================================================================
# SANDBOX PRIVATE HOSTED ZONE
# ===================================================================================
resource "aws_route53_zone" "sandbox_privatelink" {
  name = confluent_private_link_attachment.sandbox.dns_domain
  
  vpc {
    vpc_id = var.tfc_agent_vpc_id
  }

  tags = {
    Name        = "phz-confluent-privatelink-sandbox"
    Purpose     = "Sandbox Confluent PrivateLink DNS"
    Environment = confluent_environment.sandbox.display_name
    ManagedBy   = "Terraform Cloud"
  }
  
  depends_on = [ 
    module.sandbox_vpc
   ]
}

# Association with DNS VPC
resource "aws_route53_zone_association" "sandbox_to_tfc_agent_vpc" {
  zone_id = aws_route53_zone.sandbox_privatelink.zone_id
  vpc_id  = var.tfc_agent_vpc_id
}

# Association with DNS VPC
resource "aws_route53_zone_association" "sandbox_to_dns_vpc" {
  zone_id = aws_route53_zone.sandbox_privatelink.zone_id
  vpc_id  = var.dns_vpc_id
}

# Association with VPN VPC
resource "aws_route53_zone_association" "sandbox_to_vpn_vpc" {
  zone_id = aws_route53_zone.sandbox_privatelink.zone_id
  vpc_id  = var.vpn_vpc_id
}

# ===================================================================================
# SHARED PRIVATE HOSTED ZONE
# ===================================================================================
resource "aws_route53_zone" "shared_privatelink" {
  name = confluent_private_link_attachment.shared.dns_domain
  
  vpc {
    vpc_id = var.tfc_agent_vpc_id
  }

  tags = {
    Name        = "phz-confluent-privatelink-shared"
    Purpose     = "Shared Confluent PrivateLink DNS"
    Environment = confluent_environment.shared.display_name
    ManagedBy   = "Terraform Cloud"
  }
  
  depends_on = [ 
    module.shared_vpc
   ]
}

# Association with DNS VPC
resource "aws_route53_zone_association" "shared_to_tfc_agent_vpc" {
  zone_id = aws_route53_zone.shared_privatelink.zone_id
  vpc_id  = var.tfc_agent_vpc_id
}

# Association with DNS VPC
resource "aws_route53_zone_association" "shared_to_dns_vpc" {
  zone_id = aws_route53_zone.shared_privatelink.zone_id
  vpc_id  = var.dns_vpc_id
}

# Association with VPN VPC
resource "aws_route53_zone_association" "shared_to_vpn_vpc" {
  zone_id = aws_route53_zone.shared_privatelink.zone_id
  vpc_id  = var.vpn_vpc_id
}

# ===================================================================================
# SANDBOX PRIVATELINK MODULE
# ===================================================================================
module "sandbox_vpc_privatelink" {
  source = "./modules/aws-vpc-confluent-privatelink"
  
  # Transit Gateway configuration
  tgw_id                   = var.tgw_id
  tgw_rt_id                = var.tgw_rt_id

  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.sandbox.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.sandbox.dns_domain
  
  # AWS VPC configuration
  vpc_id                   = module.sandbox_vpc.vpc_id
  vpc_cidr                 = module.sandbox_vpc.vpc_cidr
  vpc_subnet_details       = module.sandbox_vpc.vpc_subnet_details
  vpc_rt_ids               = var.sandbox_vpc_rt_ids

  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.sandbox.id
  confluent_platt_id       = confluent_private_link_attachment.sandbox.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ instead of creating own
  shared_phz_id            = aws_route53_zone.sandbox_privatelink.zone_id

  depends_on = [ 
      aws_route53_zone.sandbox_privatelink
  ]
}

# ===================================================================================
# SHARED PRIVATELINK MODULE
# ===================================================================================
module "shared_vpc_privatelink" {
  source = "./modules/aws-vpc-confluent-privatelink"
  
  # Transit Gateway configuration
  tgw_id                   = var.tgw_id
  tgw_rt_id                = var.tgw_rt_id

  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.shared.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.shared.dns_domain
  
  # AWS VPC configuration
  vpc_id                   = module.shared_vpc.vpc_id
  vpc_cidr                 = module.shared_vpc.vpc_cidr
  vpc_subnet_details       = module.shared_vpc.vpc_subnet_details
  vpc_rt_ids               = var.shared_vpc_rt_ids
  
  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.shared.id
  confluent_platt_id       = confluent_private_link_attachment.shared.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ instead of creating own
  shared_phz_id            = aws_route53_zone.shared_privatelink.zone_id

  depends_on = [ 
    aws_route53_zone.shared_privatelink
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
  for_each = module.sandbox_vpc.vpc_subnet_details
  
  zone_id = aws_route53_zone.sandbox_privatelink.zone_id
  name    = "*.${each.value.availability_zone_id}.${confluent_private_link_attachment.sandbox.dns_domain}"
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
  zone_id = aws_route53_zone.sandbox_privatelink.zone_id
  name    = "*.${confluent_private_link_attachment.sandbox.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [module.sandbox_vpc_privatelink.vpc_endpoint_dns]
  
  depends_on = [module.sandbox_vpc_privatelink]
}

# Zonal records for Shared
resource "aws_route53_record" "shared_zonal" {
  for_each = module.shared_vpc.vpc_subnet_details
  
  zone_id = aws_route53_zone.shared_privatelink.zone_id
  name    = "*.${each.value.availability_zone_id}.${confluent_private_link_attachment.shared.dns_domain}"
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
  
  depends_on = [module.shared_vpc_privatelink]
}

# Wildcard record for Shared
resource "aws_route53_record" "shared_wildcard" {
  zone_id = aws_route53_zone.shared_privatelink.zone_id
  name    = "*.${confluent_private_link_attachment.shared.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [module.shared_vpc_privatelink.vpc_endpoint_dns]
  
  depends_on = [module.shared_vpc_privatelink]
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
    aws_route.vpn_to_shared_privatelink
  ]
  
  create_duration = "2m"
}
