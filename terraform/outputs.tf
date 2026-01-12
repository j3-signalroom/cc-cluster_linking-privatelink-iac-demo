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
      "${confluent_kafka_cluster.sandbox_cluster.id} (sandbox)",
      "${confluent_kafka_cluster.shared_cluster.id} (shared)",
      "All clusters in environment ${confluent_environment.non_prod.id}"
    ]
  }
}
