resource "confluent_private_link_attachment" "non_prod" {
  cloud        = "AWS"
  region       = var.aws_region
  display_name = "non-prod-aws-platt"
  
  environment {
    id = confluent_environment.non_prod.id
  }
}

# ============================================================================
# SANDBOX CLUSTER - PrivateLink Endpoint
# ============================================================================

module "sandbox_cluster_privatelink" {
  source = "./aws-privatelink-endpoint"
  
  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id     = var.sandbox_cluster_vpc_id
  subnet_ids = split(",", var.sandbox_cluster_subnet_ids)

  tfc_agent_vpc_id             = null
  associate_with_tfc_agent_vpc = false
}

resource "confluent_private_link_attachment_connection" "sandbox_cluster_plattc" {
  display_name = "sandbox-cluster-aws-plattc"
  
  environment {
    id = confluent_environment.non_prod.id
  }
  
  aws {
    vpc_endpoint_id = module.sandbox_cluster_privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.non_prod.id
  }
}

# ============================================================================
# SHARED CLUSTER - PrivateLink Endpoint
# ============================================================================

module "shared_cluster_privatelink" {
  source = "./aws-privatelink-endpoint"
  
  # PrivateLink configuration from Confluent (same attachment!)
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id     = var.shared_cluster_vpc_id
  subnet_ids = split(",", var.shared_cluster_subnet_ids)
  
  tfc_agent_vpc_id             = null
  associate_with_tfc_agent_vpc = false
  
  # Ensure sandbox creates its association first
  depends_on = [
    module.sandbox_cluster_privatelink
  ]
}

resource "confluent_private_link_attachment_connection" "shared_cluster_plattc" {
  display_name = "shared-cluster-aws-plattc"
  
  environment {
    id = confluent_environment.non_prod.id
  }
  
  aws {
    vpc_endpoint_id = module.shared_cluster_privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.non_prod.id
  }
}

# ============================================================================
# TFC AGENT - PrivateLink Endpoint
# ============================================================================
module "tfc_agent_privatelink" {
  source = "./aws-privatelink-endpoint"
  
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # TFC Agent VPC configuration
  vpc_id     = var.tfc_agent_vpc_id
  subnet_ids = split(",", var.tfc_agent_subnet_ids)
  
  tfc_agent_vpc_id             = null
  associate_with_tfc_agent_vpc = false
  
  depends_on = [
    module.sandbox_cluster_privatelink,
    module.shared_cluster_privatelink
  ]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "sandbox_cluster_deployment" {
  description = "Sandbox cluster PrivateLink deployment details"
  value = {
    vpc_id                = var.sandbox_cluster_vpc_id
    vpc_endpoint_id       = module.sandbox_cluster_privatelink.vpc_endpoint_id
    subnet_ids            = module.sandbox_cluster_privatelink.subnet_ids
    availability_zones    = module.sandbox_cluster_privatelink.availability_zones
    route53_zone_id       = module.sandbox_cluster_privatelink.route53_zone_id
    dns_domain            = module.sandbox_cluster_privatelink.route53_zone_name
    tfc_agent_association = module.sandbox_cluster_privatelink.tfc_agent_association_created
    security_group_id     = module.sandbox_cluster_privatelink.security_group_id
  }
}

output "shared_cluster_deployment" {
  description = "Shared cluster PrivateLink deployment details"
  value = {
    vpc_id                = var.shared_cluster_vpc_id
    vpc_endpoint_id       = module.shared_cluster_privatelink.vpc_endpoint_id
    subnet_ids            = module.shared_cluster_privatelink.subnet_ids
    availability_zones    = module.shared_cluster_privatelink.availability_zones
    route53_zone_id       = module.shared_cluster_privatelink.route53_zone_id
    dns_domain            = module.shared_cluster_privatelink.route53_zone_name
    tfc_agent_association = module.shared_cluster_privatelink.tfc_agent_association_created
    security_group_id     = module.shared_cluster_privatelink.security_group_id
  }
}

output "tfc_agent_integration" {
  description = "TFC Agent integration status"
  value = {
    tfc_agent_vpc_id    = var.tfc_agent_vpc_id
    associated_via      = "sandbox_cluster_privatelink"
    dns_coverage        = "Both sandbox and shared clusters (via wildcard DNS)"
    clusters_accessible = [
      "lkc-p22kk5 (sandbox)",
      "lkc-gookk1 (shared)",
      "All clusters in environment ${confluent_environment.non_prod.id}"
    ]
  }
}
