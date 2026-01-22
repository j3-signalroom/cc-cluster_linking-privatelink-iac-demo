resource "confluent_private_link_attachment" "non_prod" {
  cloud        = "AWS"
  region       = var.aws_region
  display_name = "${confluent_environment.non_prod.display_name}-aws-platt"
  
  environment {
    id = confluent_environment.non_prod.id
  }
}

# ============================================================================
# SANDBOX CLUSTER - PrivateLink Endpoint
# ============================================================================
module "sandbox_cluster_privatelink" {
  source = "./aws-confluent-privatelink"
  
  # PrivateLink configuration from Confluent
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id     = var.sandbox_cluster_vpc_id
  subnet_ids = split(",", var.sandbox_cluster_subnet_ids)

  # Enterprise configuration
  dns_vpc_id = var.dns_vpc_id

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent VPC ID
  tfc_agent_vpc_id = var.tfc_agent_vpc_id

  depends_on = [ 
    confluent_private_link_attachment.non_prod 
  ]
}

# ============================================================================
# SHARED CLUSTER - PrivateLink Endpoint
# ============================================================================
module "shared_cluster_privatelink" {
  source = "./aws-confluent-privatelink"
  
  # PrivateLink configuration from Confluent (same attachment!)
  privatelink_service_name = confluent_private_link_attachment.non_prod.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.non_prod.dns_domain
  
  # AWS VPC configuration
  vpc_id     = var.shared_cluster_vpc_id
  subnet_ids = split(",", var.shared_cluster_subnet_ids)
  
  # Enterprise configuration
  dns_vpc_id = ""

  # Confluent Cloud configuration
  confluent_environment_id = confluent_environment.non_prod.id
  confluent_platt_id       = confluent_private_link_attachment.non_prod.id

  # Terraform Cloud Agent VPC ID is not provided for shared cluster
  tfc_agent_vpc_id = ""

  depends_on = [ 
    confluent_private_link_attachment.non_prod 
  ]
}
