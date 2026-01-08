resource "confluent_private_link_attachment" "cluster_linking_demo" {
  cloud = "AWS"
  region = var.aws_region
  display_name = "cluster-linking-demo-aws-pla"
  environment {
    id = confluent_environment.cluster_linking_demo.id
  }
}

module "privatelink" {
  source                   = "./aws-privatelink-endpoint"
  vpc_id                   = var.vpc_id
  privatelink_service_name = confluent_private_link_attachment.cluster_linking_demo.aws[0].vpc_endpoint_service_name
  dns_domain               = confluent_private_link_attachment.cluster_linking_demo.dns_domain
  subnets_to_privatelink   = var.subnets_to_privatelink
}

resource "confluent_private_link_attachment_connection" "cluster_linking_demo" {
  display_name = "cluster-linking-demo-aws-plac"
  environment {
    id = confluent_environment.cluster_linking_demo.id
  }
  aws {
    vpc_endpoint_id = module.privatelink.vpc_endpoint_id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.cluster_linking_demo.id
  }
}