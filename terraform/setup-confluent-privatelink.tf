resource "confluent_private_link_attachment" "non_prod" {
  cloud        = "AWS"
  region       = var.aws_region
  display_name = "${confluent_environment.non_prod.display_name}-aws-platt"
  
  environment {
    id = confluent_environment.non_prod.id
  }
}

# ===================================================================================
# SANDBOX AWS VPC WITH TGW INTEGRATION CREATION
# ===================================================================================
module "sandbox_vpc" {
  source = "./modules/aws-vpc"
  
  vpc_name          = "sandbox-${confluent_environment.non_prod.display_name}-vpc"
  vpc_cidr          = "10.0.0.0/20"
  subnet_count      = 3
  new_bits          = 4

  depends_on = [ 
    confluent_private_link_attachment.non_prod 
  ]
}

# ===================================================================================
# SHARED (CLUSTER) AWS VPC WITH TGW INTEGRATION CREATION
# ===================================================================================
module "shared_vpc" {
  source = "./modules/aws-vpc"
  
  vpc_name          = "shared-${confluent_environment.non_prod.display_name}-vpc"
  vpc_cidr          = "10.1.0.0/20"
  subnet_count      = 3
  new_bits          = 4

  depends_on = [ 
    confluent_private_link_attachment.non_prod 
  ]
}

# ===================================================================================
# SHARED PRIVATE HOSTED ZONE
# ===================================================================================
resource "aws_route53_zone" "confluent_privatelink" {
  name = confluent_private_link_attachment.non_prod.dns_domain
  
  vpc {
    vpc_id = var.tfc_agent_vpc_id
  }

  tags = {
    Name      = "phz-confluent-privatelink-shared"
    Purpose   = "Shared PHZ for all Confluent PrivateLink connections"
    ManagedBy = "Terraform Cloud"
  }
  
  depends_on = [ 
    module.sandbox_vpc,
    module.shared_vpc
   ]
}

# ===================================================================================
# PRIVATE HOSTED ZONE VPC ASSOCIATIONS
# ===================================================================================
#
# Association with DNS VPC (for centralized DNS)
resource "aws_route53_zone_association" "dns_vpc" {
  count = var.dns_vpc_id != "" && var.dns_vpc_id != var.tfc_agent_vpc_id ? 1 : 0
  
  zone_id = aws_route53_zone.confluent_privatelink.zone_id
  vpc_id  = var.dns_vpc_id
}

# Association with VPN VPC (for VPN client connectivity)
resource "aws_route53_zone_association" "vpn_vpc" {
  count = var.vpn_vpc_id != "" && var.vpn_vpc_id != var.tfc_agent_vpc_id ? 1 : 0
  
  zone_id = aws_route53_zone.confluent_privatelink.zone_id
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
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id                   = module.sandbox_vpc.vpc_id
  vpc_cidr                 = module.sandbox_vpc.vpc_cidr
  vpc_subnet_details       = module.sandbox_vpc.vpc_subnet_details
  vpc_rt_ids               = module.sandbox_vpc.vpc_rt_ids

  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ instead of creating own
  shared_phz_id            = aws_route53_zone.confluent_privatelink.zone_id

  depends_on = [ 
      aws_route53_zone.confluent_privatelink
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
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id                   = module.shared_vpc.vpc_id
  vpc_cidr                 = module.shared_vpc.vpc_cidr
  vpc_subnet_details       = module.shared_vpc.vpc_subnet_details
  vpc_rt_ids               = module.shared_vpc.vpc_rt_ids

  # VPN configuration
  vpn_client_vpc_cidr      = var.vpn_client_vpc_cidr
  vpn_vpc_cidr             = var.vpn_vpc_cidr

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = var.tfc_agent_vpc_id 
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  # Use shared PHZ instead of creating own
  shared_phz_id            = aws_route53_zone.confluent_privatelink.zone_id

  depends_on = [ 
    aws_route53_zone.confluent_privatelink
  ]
}

# ===================================================================================
# TFC AGENT VPC ROUTES TO PRIVATELINK VPCS
# ===================================================================================
# Routes from TFC Agent VPC to Sandbox VPC (10.0.0.0/20)
resource "aws_route" "tfc_agent_to_snapshot_privatelink" {
  for_each = toset(var.tfc_agent_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.sandbox_vpc_privatelink
  ]
}

# Routes from TFC Agent VPC to Shared VPC (10.1.0.0/20)
resource "aws_route" "tfc_agent_to_shared_privatelink" {
  for_each = toset(var.tfc_agent_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.1.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.shared_vpc_privatelink
  ]
}

# ===================================================================================
# VPN CLIENT VPC ROUTES TO PRIVATELINK VPCS
# ===================================================================================
#
# Routes from VPN Client VPC to Sandbox VPC (10.0.0.0/20)
resource "aws_route" "vpn_to_sandbox_privatelink" {
  for_each = toset(var.vpn_client_vpc_rt_ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/20"
  transit_gateway_id     = var.tgw_id
  
  depends_on = [
    module.sandbox_vpc_privatelink
  ]
}

# Routes from VPN Client VPC to Shared VPC (10.1.0.0/20)
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
# DNS RECORDS - ONLY FOR PRIMARY (SHARED) VPC ENDPOINT
# ===================================================================================
#
# Primary zonal records pointing to Shared VPC endpoint
resource "aws_route53_record" "zonal" {
  for_each = module.shared_vpc.vpc_subnet_details
  
  zone_id = aws_route53_zone.confluent_privatelink.zone_id
  name    = "*.${each.value.availability_zone_id}.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60

  allow_overwrite = true
  
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
  
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [ 
    module.shared_vpc_privatelink
  ]
}

# Global wildcard CNAME pointing to Shared VPC endpoint
resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.confluent_privatelink.zone_id
  name    = "*.${confluent_private_link_attachment.non_prod.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [module.shared_vpc_privatelink.vpc_endpoint_dns]
  
  allow_overwrite = true

  depends_on = [ 
    module.shared_vpc_privatelink
  ]
}

# ===================================================================================
# WAIT FOR DNS PROPAGATION
# ===================================================================================
resource "time_sleep" "wait_for_dns" {
  depends_on = [
    module.sandbox_vpc_privatelink,
    module.shared_vpc_privatelink,
    aws_route.tfc_agent_to_snapshot_privatelink,
    aws_route.tfc_agent_to_shared_privatelink,
    aws_route53_record.zonal,
    aws_route53_record.wildcard
  ]
  
  create_duration = "1m"
}
