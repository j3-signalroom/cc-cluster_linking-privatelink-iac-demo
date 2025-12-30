# Create the Schema Registry Cluster Secrets: API Key Pair and REST endpoint for Kafka client
resource "aws_secretsmanager_secret" "schema_registry_cluster_api_key" {
    name = "${var.confluent_secret_root_path}/schema_registry_cluster"
    description = "Schema Registry Cluster secrets for Kafka client"
}

resource "aws_secretsmanager_secret_version" "schema_registry_cluster_api_key" {
    secret_id     = aws_secretsmanager_secret.schema_registry_cluster_api_key.id
    secret_string = jsonencode({"schema.registry.basic.auth.credentials.source": "USER_INFO",
                                "schema.registry.basic.auth.user.info": "${module.schema_registry_cluster_api_key_rotation.active_api_key.id}:${module.schema_registry_cluster_api_key_rotation.active_api_key.secret}",
                                "schema.registry.url": "${data.confluent_schema_registry_cluster.cluster_linking_demo.rest_endpoint}"})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_source_app_manager_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_manager/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_source_app_manager_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_manager_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_source_app_manager_api_key.active_api_key.id}' password='${module.kafka_source_app_manager_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Python client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_source_app_manager_cluster_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_manager/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_manager_cluster_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_manager_cluster_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_manager_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_manager_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_source_app_consumer_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_consumer/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_source_app_consumer_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_consumer_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_source_app_consumer_api_key.active_api_key.id}' password='${module.kafka_source_app_consumer_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_source_app_consumer_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_consumer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_consumer_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_consumer_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_consumer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_consumer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_source_app_producer_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_producer/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_source_app_producer_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_producer_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_source_app_producer_api_key.active_api_key.id}' password='${module.kafka_source_app_producer_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_source_app_producer_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/source_cluster/app_producer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_source_app_producer_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_source_app_producer_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_source_app_producer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_source_app_producer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.source.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_destination_app_manager_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_manager/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_destination_app_manager_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_manager_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_destination_app_manager_api_key.active_api_key.id}' password='${module.kafka_destination_app_manager_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Python client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_destination_app_manager_cluster_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_manager/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_destination_app_manager_cluster_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_manager_cluster_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_destination_app_manager_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_destination_app_manager_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_destination_app_consumer_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_consumer/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_destination_app_consumer_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_consumer_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_destination_app_consumer_api_key.active_api_key.id}' password='${module.kafka_destination_app_consumer_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_destination_app_consumer_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_consumer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_destination_app_consumer_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_consumer_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_destination_app_consumer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_destination_app_consumer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Java client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "kafka_destination_app_producer_api_key_java_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_producer/java_client"
    description = "Kafka Cluster secrets for Java client"
}
resource "aws_secretsmanager_secret_version" "kafka_destination_app_producer_api_key_java_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_producer_api_key_java_client.id
    secret_string = jsonencode({"sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='${module.kafka_destination_app_producer_api_key.active_api_key.id}' password='${module.kafka_destination_app_producer_api_key.active_api_key.secret}';",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "kafka_destination_app_producer_api_key_python_client" {
    name = "${var.confluent_secret_root_path}/destination_cluster/app_producer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "kafka_destination_app_producer_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.kafka_destination_app_producer_api_key_python_client.id
    secret_string = jsonencode({"sasl.username": "${module.kafka_destination_app_producer_api_key.active_api_key.id}",
                                "sasl.password": "${module.kafka_destination_app_producer_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.destination.bootstrap_endpoint, "SASL_SSL://", "")})
}
