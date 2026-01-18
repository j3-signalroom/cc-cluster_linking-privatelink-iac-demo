# aws-privatelink-endpoint/outputs.tf
# PRODUCTION VERSION - Manual Subnet IDs

output "vpc_endpoint_id" {
  description = "VPC Endpoint ID"
  value       = aws_vpc_endpoint.privatelink.id
}

output "vpc_endpoint_dns_name" {
  description = "VPC Endpoint primary DNS name"
  value       = aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"]
}

output "route53_zone_id" {
  description = "Route53 Private Hosted Zone ID"
  value       = aws_route53_zone.privatelink.zone_id
}

output "route53_zone_name" {
  description = "Route53 Private Hosted Zone name"
  value       = aws_route53_zone.privatelink.name
}

output "subnet_ids" {
  description = "Subnet IDs used for the VPC endpoint"
  value       = var.subnet_ids
}

output "availability_zones" {
  description = "Availability zones where VPC endpoint is deployed"
  value       = [for id in var.subnet_ids : data.aws_availability_zone.privatelink[id].name]
}

output "security_group_id" {
  description = "Security group ID attached to the VPC endpoint"
  value       = aws_security_group.privatelink.id
}

output "inbound_resolver_ips" {
  description = "IP addresses of the inbound resolver endpoint"
  value       = aws_route53_resolver_endpoint.inbound.ip_address[*].ip
}

output "outbound_resolver_id" {
  description = "ID of the outbound resolver endpoint"
  value       = aws_route53_resolver_endpoint.outbound.id
}

output "resolver_rule_id" {
  description = "ID of the resolver rule"
  value       = aws_route53_resolver_rule.confluent_cloud.id
}