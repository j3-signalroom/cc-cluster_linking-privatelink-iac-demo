resource "confluent_private_link_attachment" "sandbox_cluster" {
  cloud = "AWS"
  region = var.aws_region
  display_name = "sandbox-cluster-aws-platt"
  environment {
    id = confluent_environment.non_prod.id
  }
}

module "sandbox_cluster_privatelink" {
  source                   = "./aws-privatelink-endpoint"
  vpc_id                   = var.sandbox_cluster_vpc_id
  privatelink_service_name = confluent_private_link_attachment.sandbox_cluster.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.sandbox_cluster.dns_domain
  subnets_to_privatelink   = var.sandbox_cluster_subnets_to_privatelink
}

resource "confluent_private_link_attachment_connection" "sandbox_cluster" {
  display_name = "sandbox-cluster-aws-plattc"
  environment {
    id = confluent_environment.non_prod.id
  }
  aws {
    vpc_endpoint_id = module.sandbox_cluster_privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.sandbox_cluster.id
  }
}

resource "confluent_private_link_attachment" "shared_cluster" {
  cloud = "AWS"
  region = var.aws_region
  display_name = "shared-cluster-aws-platt"
  environment {
    id = confluent_environment.non_prod.id
  }
}

module "shared_cluster_privatelink" {
  source                   = "./aws-privatelink-endpoint"
  vpc_id                   = var.shared_cluster_vpc_id
  privatelink_service_name = confluent_private_link_attachment.shared_cluster.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.shared_cluster.dns_domain
  subnets_to_privatelink   = var.shared_cluster_subnets_to_privatelink
}

resource "confluent_private_link_attachment_connection" "shared_cluster" {
  display_name = "shared-cluster-aws-plattc"
  environment {
    id = confluent_environment.non_prod.id
  }
  aws {
    vpc_endpoint_id = module.shared_cluster_privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.shared_cluster.id
  }
}