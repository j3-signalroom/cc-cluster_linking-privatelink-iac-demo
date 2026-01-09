output "tfc_agent_vpc_id" {
  description = "VPC ID where TFC Agent is running"
  value       = data.aws_subnet.tfc_agent.vpc_id
}

output "zone_associations_created" {
  description = "Which Route 53 zone associations were created"
  value = {
    sandbox_to_agent   = data.aws_subnet.tfc_agent.vpc_id != var.sandbox_cluster_vpc_id
    shared_to_agent    = data.aws_subnet.tfc_agent.vpc_id != var.shared_cluster_vpc_id
    shared_to_sandbox  = data.aws_subnet.tfc_agent.vpc_id == var.sandbox_cluster_vpc_id
    sandbox_to_shared  = data.aws_subnet.tfc_agent.vpc_id == var.shared_cluster_vpc_id
  }
}

output "agent_vpc_matches" {
  description = "Which VPC the agent is in"
  value = {
    in_sandbox_vpc = data.aws_subnet.tfc_agent.vpc_id == var.sandbox_cluster_vpc_id
    in_shared_vpc  = data.aws_subnet.tfc_agent.vpc_id == var.shared_cluster_vpc_id
    in_different_vpc = data.aws_subnet.tfc_agent.vpc_id != var.sandbox_cluster_vpc_id && data.aws_subnet.tfc_agent.vpc_id != var.shared_cluster_vpc_id
  }
}