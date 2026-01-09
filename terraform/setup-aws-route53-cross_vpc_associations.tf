# Associate sandbox cluster's Route 53 Private Hosted Zone with TFC Agent VPC
# This allows the agent to resolve sandbox cluster DNS names
resource "aws_route53_zone_association" "sandbox_to_agent" {
  # Only create if agent VPC is different from sandbox VPC
  count = data.aws_subnet.tfc_agent.vpc_id != var.sandbox_cluster_vpc_id ? 1 : 0

  zone_id = module.sandbox_cluster_privatelink.route53_zone_id
  vpc_id  = data.aws_subnet.tfc_agent.vpc_id
}

# Associate shared cluster's Route 53 Private Hosted Zone with TFC Agent VPC
# This allows the agent to resolve shared cluster DNS names
resource "aws_route53_zone_association" "shared_to_agent" {
  # Only create if agent VPC is different from shared VPC
  count = data.aws_subnet.tfc_agent.vpc_id != var.shared_cluster_vpc_id ? 1 : 0

  zone_id = module.shared_cluster_privatelink.route53_zone_id
  vpc_id  = data.aws_subnet.tfc_agent.vpc_id
}

# If agent is IN sandbox VPC, associate shared cluster's PHZ with it
resource "aws_route53_zone_association" "shared_to_sandbox" {
  # Only create if agent is in sandbox VPC
  count = data.aws_subnet.tfc_agent.vpc_id == var.sandbox_cluster_vpc_id ? 1 : 0

  zone_id = module.shared_cluster_privatelink.route53_zone_id
  vpc_id  = var.sandbox_cluster_vpc_id
}

# If agent is IN shared VPC, associate sandbox cluster's PHZ with it
resource "aws_route53_zone_association" "sandbox_to_shared" {
  # Only create if agent is in shared VPC
  count = data.aws_subnet.tfc_agent.vpc_id == var.shared_cluster_vpc_id ? 1 : 0

  zone_id = module.sandbox_cluster_privatelink.route53_zone_id
  vpc_id  = var.shared_cluster_vpc_id
}

# Add a time_sleep to wait for DNS association to propagate
resource "time_sleep" "wait_for_zone_associations" {
  depends_on = [
    aws_route53_zone_association.sandbox_to_agent,
    aws_route53_zone_association.shared_to_agent,
    aws_route53_zone_association.shared_to_sandbox,
    aws_route53_zone_association.sandbox_to_shared
  ]

  create_duration = "60s"
}
