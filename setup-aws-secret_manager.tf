# Create the Schema Registry Cluster Secrets: API Key Pair and REST endpoint for Python client
resource "aws_secretsmanager_secret" "schema_registry_cluster_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/schema_registry_cluster/python_client"
    description = "Schema Registry Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "schema_registry_cluster_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.schema_registry_cluster_api_key_python_client.id
    secret_string = jsonencode({"schema.registry.basic.auth.credentials.source": "USER_INFO",
                                "schema.registry.basic.auth.user.info": "${module.schema_registry_cluster_api_key_rotation.active_api_key.id}:${module.schema_registry_cluster_api_key_rotation.active_api_key.secret}",
                                "schema.registry.url": "${data.confluent_schema_registry_cluster.env.rest_endpoint}"})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Python client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_app_manager_cluster_api_key" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_manager/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_manager_cluster_api_key" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_manager_cluster_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_manager_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_manager_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_app_consumer_api_key" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_consumer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_consumer_api_key" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_consumer_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_consumer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_consumer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_app_producer_api_key" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_producer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_producer_api_key" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_producer_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_producer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_producer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}
