# Create the Kafka cluster
resource "confluent_kafka_cluster" "shared_cluster" {
  display_name = "shared_cluster"
  availability = "HIGH"
  cloud        = local.cloud
  region       = var.aws_region
  enterprise   {}
  
  environment {
    id = confluent_environment.non_prod.id
  }

  network {
    id = confluent_network.non_prod.id  # This makes it use PrivateLink
  }
}

resource "time_sleep" "wait_for_shared_dns" {
  depends_on = [
    module.shared_cluster_privatelink,
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    confluent_kafka_cluster.shared_cluster
  ]
  create_duration = "3m"
}

resource "confluent_service_account" "shared_cluster_app_manager" {
  display_name = "shared_cluster_app_manager"
  description  = "Shared Cluster Sharing Service account to manage Kafka cluster"

  depends_on = [ 
    confluent_kafka_cluster.shared_cluster 
  ]
}

resource "confluent_role_binding" "shared_cluster_app_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.shared_cluster_app_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.shared_cluster.rbac_crn

  depends_on = [ 
    confluent_service_account.shared_cluster_app_manager 
  ]
}

# Creates the shared_cluster_app_manager Kafka Cluster API Key Pairs, rotate them in accordance to a time schedule,
# and provide the current acitve API Key Pair to use
module "kafka_shared_cluster_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.shared_cluster_app_manager.id
    api_version = confluent_service_account.shared_cluster_app_manager.api_version
    kind        = confluent_service_account.shared_cluster_app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.shared_cluster.id
    api_version = confluent_kafka_cluster.shared_cluster.api_version
    kind        = confluent_kafka_cluster.shared_cluster.kind

    environment = {
      id = confluent_environment.non_prod.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
  disable_wait_for_ready       = true

  depends_on = [
    confluent_role_binding.shared_cluster_app_manager_kafka_cluster_admin,
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    time_sleep.wait_for_shared_dns
  ]
}

resource "confluent_service_account" "shared_cluster_app_consumer" {
  display_name = "shared_cluster_app_consumer"
  description  = "Shared Cluster App Consumer Service account to consume from 'stock_trades' topic"
}

module "kafka_shared_cluster_app_consumer_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.shared_cluster_app_consumer.id
    api_version = confluent_service_account.shared_cluster_app_consumer.api_version
    kind        = confluent_service_account.shared_cluster_app_consumer.kind
  }

  resource = {
    id          = confluent_kafka_cluster.shared_cluster.id
    api_version = confluent_kafka_cluster.shared_cluster.api_version
    kind        = confluent_kafka_cluster.shared_cluster.kind

    environment = {
      id = confluent_environment.non_prod.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
  disable_wait_for_ready       = true

  depends_on = [
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    time_sleep.wait_for_shared_dns
  ]
}

resource "confluent_kafka_acl" "shared_cluster_app_consumer_read_on_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.shared_cluster.id
  }
  resource_type = "GROUP"
  resource_name = "cluster_linking_demo_"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.shared_cluster_app_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.shared_cluster.rest_endpoint
  credentials {
    key    = module.kafka_shared_cluster_app_manager_api_key.active_api_key.id
    secret = module.kafka_shared_cluster_app_manager_api_key.active_api_key.secret
  }

  depends_on = [
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    time_sleep.wait_for_shared_dns
  ]
}
