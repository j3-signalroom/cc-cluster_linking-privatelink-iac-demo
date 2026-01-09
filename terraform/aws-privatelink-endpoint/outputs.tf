output "vpc_endpoint_id" {
  description = "The ID of the VPC endpoint"
  value       = aws_vpc_endpoint.privatelink.id
}

output "route53_zone_id" {
  description = "The ID of the Route 53 Private Hosted Zone"
  value       = aws_route53_zone.privatelink.zone_id
}

output "route53_zone_name" {
  description = "The name of the Route 53 Private Hosted Zone"
  value       = aws_route53_zone.privatelink.name
}

output "dns_records" {
  description = "Map of DNS record names created in the zone"
  value = {
    for k, v in aws_route53_record.privatelink : k => v.name
  }
}