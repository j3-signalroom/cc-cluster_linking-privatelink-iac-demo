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

# Tell Confluent to accept the TFC agent VPC endpoint
resource "confluent_private_link_attachment_connection" "tfc_agent_plattc" {
  display_name = "tfc-agent-aws-plattc"
  
  environment {
    id = confluent_environment.non_prod.id
  }
  
  aws {
    vpc_endpoint_id = module.tfc_agent_privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.non_prod.id
  }
  
  depends_on = [
    module.tfc_agent_privatelink
  ]
}
