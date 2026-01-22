output "sandbox_cluster_deployment" {
  description = "Sandbox cluster PrivateLink deployment details"
  value = {
    vpc_id                = var.sandbox_cluster_vpc_id
    vpc_endpoint_id       = module.sandbox_cluster_privatelink.vpc_endpoint_id
    subnet_ids            = module.sandbox_cluster_privatelink.subnet_ids
    availability_zones    = module.sandbox_cluster_privatelink.availability_zones
    route53_zone_id       = module.sandbox_cluster_privatelink.route53_zone_id
    dns_domain            = module.sandbox_cluster_privatelink.route53_zone_name
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
    security_group_id     = module.shared_cluster_privatelink.security_group_id
  }
}
