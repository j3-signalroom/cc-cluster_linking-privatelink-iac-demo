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
# SHARED AWS VPC WITH TGW INTEGRATION CREATION
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
  vpc_rt_id                = module.sandbox_vpc.vpc_rt_id

  # VPN Client configuration
  vpn_client_cidr          = var.vpn_client_cidr

  # DNS VPC configuration
  dns_vpc_id               = var.dns_vpc_id

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = ""
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  shared_phz_id            = aws_route53_zone.confluent_privatelink.zone_id

  depends_on = [ 
      
  ]
}

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
  vpc_rt_id                = module.shared_vpc.vpc_rt_id

  # VPN Client configuration
  vpn_client_cidr          = var.vpn_client_cidr

  # DNS VPC configuration
  dns_vpc_id               = var.dns_vpc_id

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent configuration
  tfc_agent_vpc_id         = ""
  tfc_agent_vpc_cidr       = var.tfc_agent_vpc_cidr

  shared_phz_id            = aws_route53_zone.confluent_privatelink.zone_id

  depends_on = [ 
    aws_route53_zone.confluent_privatelink
  ]
}

# Step 3: Add routes from TFC Agent VPC to PrivateLink VPCs
# ============================================================================

# Get TFC Agent VPC route tables
data "aws_route_tables" "tfc_agent" {
  vpc_id = var.tfc_agent_vpc_id
  
  filter {
    name   = "association.main"
    values = ["false"]
  }
}

# Add routes to Sandbox PrivateLink VPC
resource "aws_route" "tfc_to_sandbox_privatelink" {
  for_each = toset(data.aws_route_tables.tfc_agent.ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.0.0.0/20"
  transit_gateway_id     = var.tgw_id
}

# Add routes to Shared PrivateLink VPC
resource "aws_route" "tfc_to_shared_privatelink" {
  for_each = toset(data.aws_route_tables.tfc_agent.ids)
  
  route_table_id         = each.value
  destination_cidr_block = "10.1.0.0/20"
  transit_gateway_id     = var.tgw_id
}

# Step 4: Add explicit dependency for Confluent resources
# ============================================================================

# Make sure Confluent API keys wait for DNS to be ready
resource "time_sleep" "wait_for_dns" {
  depends_on = [
    module.sandbox_vpc_privatelink,
    module.shared_vpc_privatelink
  ]
  
  create_duration = "2m"
}
