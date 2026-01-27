
output "privatelink_dns_domain" {
  value       = confluent_private_link_attachment.non_prod.dns_domain
  description = "Confluent PrivateLink DNS domain (e.g., xyz789.us-east-1.aws.private.confluent.cloud)"
}

output "sandbox_vpc_endpoint_id" {
  description = "Sandbox VPC Endpoint ID"
  value       = module.sandbox_vpc_privatelink.vpc_endpoint_id
}

output "shared_vpc_endpoint_id" {
  description = "Shared VPC Endpoint ID"
  value       = module.shared_vpc_privatelink.vpc_endpoint_id
}

output "verification" {
  value = {
    sandbox = {
      environment_id  = confluent_environment.non_prod.id
      dns_domain      = confluent_private_link_attachment.non_prod.dns_domain
      vpc_id          = module.sandbox_vpc.vpc_id
      vpc_cidr        = module.sandbox_vpc.vpc_cidr
      endpoint_id     = module.sandbox_vpc_privatelink.vpc_endpoint_id
      phz_id          = aws_route53_zone.centralized_dns_vpc.zone_id
    }
    shared = {
      environment_id  = confluent_environment.non_prod.id
      dns_domain      = confluent_private_link_attachment.non_prod.dns_domain
      vpc_id          = module.shared_vpc.vpc_id
      vpc_cidr        = module.shared_vpc.vpc_cidr
      endpoint_id     = module.shared_vpc_privatelink.vpc_endpoint_id
      phz_id          = aws_route53_zone.centralized_dns_vpc.zone_id
    }
  }
  description = "Verification information for both environments"
}

output "centralized_phz_id" {
  description = "Centralized Private Hosted Zone ID"
  value       = aws_route53_zone.centralized_dns_vpc.zone_id
}

output "centralized_phz_name_servers" {
  description = "Private Hosted Zone name servers"
  value       = aws_route53_zone.centralized_dns_vpc.name_servers
}

output "system_resolver_rule_id" {
  description = "SYSTEM resolver rule ID"
  value       = aws_route53_resolver_rule.confluent_private_system.id
}
