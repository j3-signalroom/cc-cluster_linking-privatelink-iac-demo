resource "confluent_cluster_link" "source-to-destination" {
  link_name = "bidirectional-link"
  link_mode = "BIDIRECTIONAL"
  local_kafka_cluster {
    id            = confluent_kafka_cluster.source.id
    rest_endpoint = confluent_kafka_cluster.source.rest_endpoint
    credentials {
      key    = module.kafka_source_app_manager_api_key.active_api_key.id
      secret = module.kafka_source_app_manager_api_key.active_api_key.secret
    }
  }

  remote_kafka_cluster {
    id                 = confluent_kafka_cluster.destination.id
    bootstrap_endpoint = confluent_kafka_cluster.destination.bootstrap_endpoint
    credentials {
      key    = module.kafka_destination_app_manager_api_key.active_api_key.id
      secret = module.kafka_destination_app_manager_api_key.active_api_key.secret
    }
  }

  depends_on = [ 
    confluent_kafka_cluster.source,
    confluent_kafka_cluster.destination,
    module.kafka_source_app_manager_api_key.active_api_key,
    module.kafka_destination_app_manager_api_key.active_api_key
  ]
}