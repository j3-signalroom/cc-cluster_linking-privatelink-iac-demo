resource "confluent_cluster_link" "sandbox-to-shared" {
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
    confluent_kafka_cluster.shared_cluster,
    module.kafka_shared_cluster_app_manager_api_key.active_api_key
  ]
}