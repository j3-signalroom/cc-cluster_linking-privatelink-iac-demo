resource "confluent_cluster_link" "sandbox_to_shared" {
  link_name = "bidirectional-link"
  link_mode = "BIDIRECTIONAL"
  local_kafka_cluster {
    id            = confluent_kafka_cluster.sandbox_cluster.id
    rest_endpoint = confluent_kafka_cluster.sandbox_cluster.rest_endpoint
    credentials {
      key    = module.kafka_sandbox_cluster_app_manager_api_key.active_api_key.id
      secret = module.kafka_sandbox_cluster_app_manager_api_key.active_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.shared_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.shared_cluster.bootstrap_endpoint
    credentials {
      key    = module.kafka_shared_cluster_app_manager_api_key.active_api_key.id
      secret = module.kafka_shared_cluster_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [ 
    confluent_kafka_cluster.sandbox_cluster,
    module.kafka_sandbox_cluster_app_manager_api_key.active_api_key,
    time_sleep.wait_for_sandbox_dns,
    confluent_kafka_cluster.shared_cluster,
    module.kafka_shared_cluster_app_manager_api_key.active_api_key,
    time_sleep.wait_for_shared_dns,
    confluent_private_link_attachment_connection.sandbox_cluster_plattc,
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    confluent_private_link_attachment_connection.tfc_agent_plattc
  ]
}

resource "confluent_service_account" "cluster_linking_sandbox_cluster_app_manager" {
  display_name = "cluster_linking_sandbox_cluster_app_manager"
  description  = "Cluster Linking Sandbox Cluster Service account to manage Kafka cluster source"

  depends_on = [ 
    confluent_cluster_link.sandbox_to_shared
  ]
}

resource "confluent_role_binding" "cluster_linking_sandbox_cluster_app_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_linking_sandbox_cluster_app_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.sandbox_cluster.rbac_crn

  depends_on = [ 
    confluent_service_account.cluster_linking_sandbox_cluster_app_manager
  ]
}

# Creates the cluster_linking_sandbox_cluster_app_manager Kafka Cluster API Key Pairs, rotate them in accordance to a time schedule,
# and provide the current acitve API Key Pair to use
module "cluster_linking_sandbox_cluster_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.cluster_linking_sandbox_cluster_app_manager.id
    api_version = confluent_service_account.cluster_linking_sandbox_cluster_app_manager.api_version
    kind        = confluent_service_account.cluster_linking_sandbox_cluster_app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.sandbox_cluster.id
    api_version = confluent_kafka_cluster.sandbox_cluster.api_version
    kind        = confluent_kafka_cluster.sandbox_cluster.kind

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
    confluent_role_binding.cluster_linking_sandbox_cluster_app_manager_kafka_cluster_admin
  ]
}

resource "confluent_service_account" "cluster_linking_shared_cluster_app_manager" {
  display_name = "cluster_linking_shared_cluster_app_manager"
  description  = "Cluster Linking Shared Cluster Service account to manage Kafka cluster source"

  depends_on = [ 
    confluent_cluster_link.sandbox_to_shared 
  ]
}

resource "confluent_role_binding" "cluster_linking_shared_cluster_app_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_linking_shared_cluster_app_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.shared_cluster.rbac_crn

  depends_on = [ 
    confluent_service_account.cluster_linking_shared_cluster_app_manager
  ]
}

# Creates the cluster_linking_shared_cluster_app_manager Kafka Cluster API Key Pairs, rotate them in accordance to a time schedule,
# and provide the current acitve API Key Pair to use
module "cluster_linking_shared_cluster_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.cluster_linking_shared_cluster_app_manager.id
    api_version = confluent_service_account.cluster_linking_shared_cluster_app_manager.api_version
    kind        = confluent_service_account.cluster_linking_shared_cluster_app_manager.kind
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
    confluent_role_binding.cluster_linking_shared_cluster_app_manager_kafka_cluster_admin
  ]
}

resource "confluent_kafka_mirror_topic" "stock_trades_mirror" {
  source_kafka_topic {
    topic_name = confluent_kafka_topic.source_stock_trades.topic_name 
  }
  cluster_link {
    link_name = confluent_cluster_link.sandbox_to_shared.link_name
  }
  
  kafka_cluster {
    id            = confluent_kafka_cluster.shared_cluster.id
    rest_endpoint = confluent_kafka_cluster.shared_cluster.rest_endpoint

    credentials {
      key    = module.cluster_linking_shared_cluster_app_manager_api_key.active_api_key.id
      secret = module.cluster_linking_shared_cluster_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [ 
    confluent_cluster_link.sandbox_to_shared,
    module.cluster_linking_sandbox_cluster_app_manager_api_key.active_api_key,
    module.cluster_linking_shared_cluster_app_manager_api_key.active_api_key,
    confluent_kafka_topic.source_stock_trades,
    confluent_private_link_attachment_connection.sandbox_cluster_plattc,
    confluent_private_link_attachment_connection.shared_cluster_plattc,
    confluent_private_link_attachment_connection.tfc_agent_plattc
  ]
}
