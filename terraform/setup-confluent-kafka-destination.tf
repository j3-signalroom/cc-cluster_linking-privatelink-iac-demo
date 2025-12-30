# Create the Kafka cluster
resource "confluent_kafka_cluster" "destination" {
  display_name = "destination"
  availability = "SINGLE_ZONE"
  cloud        = local.cloud
  region       = var.aws_region
  standard     {}

  environment {
    id = confluent_environment.cluster_linking_demo.id
  }
}

# 'destination_app_manager' service account is required in this configuration to create 'stock_trades' topic and grant ACLs
# to 'destination_app_producer' and 'destination_app_consumer' service accounts.
resource "confluent_service_account" "destination_app_manager" {
  display_name = "destination_app_manager"
  description  = "Sandbox Cluster Sharing Service account to manage Kafka cluster"

  depends_on = [ 
    confluent_kafka_cluster.destination 
  ]
}

resource "confluent_role_binding" "destination_app_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.destination_app_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.destination.rbac_crn

  depends_on = [ 
    confluent_service_account.destination_app_manager 
  ]
}

# Creates the destination_app_manager Kafka Cluster API Key Pairs, rotate them in accordance to a time schedule,
# and provide the current acitve API Key Pair to use
module "kafka_destination_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.destination_app_manager.id
    api_version = confluent_service_account.destination_app_manager.api_version
    kind        = confluent_service_account.destination_app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.destination.id
    api_version = confluent_kafka_cluster.destination.api_version
    kind        = confluent_kafka_cluster.destination.kind

    environment = {
      id = confluent_environment.cluster_linking_demo.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}

# Create the `stock_trades` Kafka topic
resource "confluent_kafka_topic" "destination_stock_trades" {
  kafka_cluster {
    id = confluent_kafka_cluster.destination.id
  }
  topic_name    = "stock_trades"
  rest_endpoint = confluent_kafka_cluster.destination.rest_endpoint
  credentials {
    key    = module.kafka_destination_app_manager_api_key.active_api_key.id
    secret = module.kafka_destination_app_manager_api_key.active_api_key.secret
  }

  depends_on = [ 
    confluent_role_binding.destination_app_manager_kafka_cluster_admin,
    module.kafka_destination_app_manager_api_key 
  ]
}

resource "confluent_service_account" "destination_app_consumer" {
  display_name = "destination_app_consumer"
  description  = "Cluster Linking Demo Service account to consume from 'stock_trades' topic of Kafka cluster destination"
}

module "kafka_destination_app_consumer_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.destination_app_consumer.id
    api_version = confluent_service_account.destination_app_consumer.api_version
    kind        = confluent_service_account.destination_app_consumer.kind
  }

  resource = {
    id          = confluent_kafka_cluster.destination.id
    api_version = confluent_kafka_cluster.destination.api_version
    kind        = confluent_kafka_cluster.destination.kind

    environment = {
      id = confluent_environment.cluster_linking_demo.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}

resource "confluent_kafka_acl" "destination_app_producer_write_on_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.destination.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.destination_stock_trades.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.destination_app_producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.destination.rest_endpoint
  credentials {
    key    = module.kafka_destination_app_manager_api_key.active_api_key.id
    secret = module.kafka_destination_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_service_account" "destination_app_producer" {
  display_name = "destination_app_producer"
  description  = "Sandbox Cluster Sharing Service account to produce to 'stock_trades' topic of Kafka cluster"
}

module "kafka_destination_app_producer_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.destination_app_producer.id
    api_version = confluent_service_account.destination_app_producer.api_version
    kind        = confluent_service_account.destination_app_producer.kind
  }

  resource = {
    id          = confluent_kafka_cluster.destination.id
    api_version = confluent_kafka_cluster.destination.api_version
    kind        = confluent_kafka_cluster.destination.kind

    environment = {
      id = confluent_environment.cluster_linking_demo.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}


resource "confluent_kafka_acl" "destination_app_consumer_read_on_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.destination.id
  }
  resource_type = "GROUP"
  resource_name = "cluster_linking_demo"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.destination_app_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.destination.rest_endpoint
  credentials {
    key    = module.kafka_destination_app_manager_api_key.active_api_key.id
    secret = module.kafka_destination_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_kafka_acl" "destination_app_consumer_read_on_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.destination.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.destination_stock_trades.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.destination_app_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.destination.rest_endpoint
  credentials {
    key    = module.kafka_destination_app_manager_api_key.active_api_key.id
    secret = module.kafka_destination_app_manager_api_key.active_api_key.secret
  }
}
