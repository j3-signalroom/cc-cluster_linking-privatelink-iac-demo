resource "confluent_service_account" "sandbox_cluster_linking_app_manager" {
  display_name = "sandbox_cluster_linking_app_manager"
  description  = "Sandbox Cluster Linking App Manager Service Account"
}

resource "confluent_role_binding" "sandbox_cluster_linking_app_manager" {
  principal   = "User:${confluent_service_account.sandbox_cluster_linking_app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.non_prod.resource_name
}

module "sandbox_cluster_linking_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.sandbox_cluster_linking_app_manager.id
    api_version = confluent_service_account.sandbox_cluster_linking_app_manager.api_version
    kind        = confluent_service_account.sandbox_cluster_linking_app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.sandbox_cluster.id
    api_version = confluent_kafka_cluster.sandbox_cluster.api_version
    kind        = confluent_kafka_cluster.sandbox_cluster.kind

    environment = {
      id = confluent_environment.non_prod.id
    }
  }

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count

  depends_on = [ 
    confluent_kafka_cluster.sandbox_cluster,
    module.sandbox_vpc_privatelink
  ]
}

resource "confluent_service_account" "shared_cluster_linking_app_manager" {
  display_name = "shared_cluster_linking_app_manager"
  description  = "Shared Cluster Linking App Manager Service Account"
}

resource "confluent_role_binding" "shared_cluster_linking_app_manager" {
  principal   = "User:${confluent_service_account.shared_cluster_linking_app_manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.non_prod.resource_name
}

module "shared_cluster_linking_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.shared_cluster_linking_app_manager.id
    api_version = confluent_service_account.shared_cluster_linking_app_manager.api_version
    kind        = confluent_service_account.shared_cluster_linking_app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.shared_cluster.id
    api_version = confluent_kafka_cluster.shared_cluster.api_version
    kind        = confluent_kafka_cluster.shared_cluster.kind

    environment = {
      id = confluent_environment.non_prod.id
    }
  }

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count

  depends_on = [ 
    confluent_kafka_cluster.shared_cluster,
    module.shared_vpc_privatelink
  ]
}

resource "confluent_cluster_link" "sandbox_and_shared" {
  link_name = "bidirectional-between-sandbox-and-shared"
  link_mode = "BIDIRECTIONAL"
  local_kafka_cluster {
    id            = confluent_kafka_cluster.sandbox_cluster.id
    rest_endpoint = confluent_kafka_cluster.sandbox_cluster.rest_endpoint
    credentials {
      key    = module.sandbox_cluster_linking_app_manager_api_key.active_api_key.id
      secret = module.sandbox_cluster_linking_app_manager_api_key.active_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.shared_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.shared_cluster.bootstrap_endpoint
    credentials {
      key    = module.shared_cluster_linking_app_manager_api_key.active_api_key.id
      secret = module.shared_cluster_linking_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [
    module.sandbox_vpc_privatelink,
    module.shared_vpc_privatelink
  ]
}

# Reverse link: Shared -> Sandbox (required for bidirectional mode)
resource "confluent_cluster_link" "shared_to_sandbox" {
  link_name = "bidirectional-between-sandbox-and-shared"
  link_mode = "BIDIRECTIONAL"
  
  local_kafka_cluster {
    id            = confluent_kafka_cluster.shared_cluster.id
    rest_endpoint = confluent_kafka_cluster.shared_cluster.rest_endpoint
    credentials {
      key    = module.shared_cluster_linking_app_manager_api_key.active_api_key.id
      secret = module.shared_cluster_linking_app_manager_api_key.active_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.sandbox_cluster.id
    bootstrap_endpoint = confluent_kafka_cluster.sandbox_cluster.bootstrap_endpoint
    credentials {
      key    = module.sandbox_cluster_linking_app_manager_api_key.active_api_key.id
      secret = module.sandbox_cluster_linking_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [
    confluent_cluster_link.sandbox_and_shared
  ]
}

resource "confluent_kafka_mirror_topic" "stock_trades_mirror" {
  source_kafka_topic {
    topic_name = confluent_kafka_topic.source_stock_trades.topic_name 
  }
  cluster_link {
    link_name = confluent_cluster_link.sandbox_and_shared.link_name
  }
  
  kafka_cluster {
    id            = confluent_kafka_cluster.shared_cluster.id
    rest_endpoint = confluent_kafka_cluster.shared_cluster.rest_endpoint

    credentials {
      key    = module.shared_cluster_linking_app_manager_api_key.active_api_key.id
      secret = module.shared_cluster_linking_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [ 
    confluent_cluster_link.shared_to_sandbox
  ]
}
