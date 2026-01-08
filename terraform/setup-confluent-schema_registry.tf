# Create the Service Account for the Kafka Cluster API
resource "confluent_service_account" "schema_registry_cluster_api" {
    display_name = "cluster_linking_demo_schema_registry_cluster_api"
    description  = "Sandbox Cluster Sharing Schema Registry Cluster API Service Account"
}

resource "confluent_schema_registry_cluster" "cluster_linking_demo" {
  package = "ESSENTIALS"
  
  environment {
    id = confluent_environment.cluster_linking_demo.id
  }

  region {
    id = var.aws_region
  }

  # Wait for PrivateLink connection
  depends_on = [
    confluent_private_link_attachment_connection.cluster_linking_demo
  ]
}

# Create the Environment API Key Pairs, rotate them in accordance to a time schedule, and provide the current
# acitve API Key Pair to use
module "schema_registry_cluster_api_key_rotation" {
    
    source  = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

    # Required Input(s)
    owner = {
        id          = confluent_service_account.schema_registry_cluster_api.id
        api_version = confluent_service_account.schema_registry_cluster_api.api_version
        kind        = confluent_service_account.schema_registry_cluster_api.kind
    }

    resource = {
        id          = data.confluent_schema_registry_cluster.cluster_linking_demo.id
        api_version = data.confluent_schema_registry_cluster.cluster_linking_demo.api_version
        kind        = data.confluent_schema_registry_cluster.cluster_linking_demo.kind

        environment = {
            id = confluent_environment.cluster_linking_demo.id
        }
    }

    confluent_api_key    = var.confluent_api_key
    confluent_api_secret = var.confluent_api_secret

    # Optional Input(s)
    key_display_name = "Confluent Schema Registry Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
    number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
    day_count = var.day_count
}

resource "confluent_role_binding" "schema_registry_developer_read_all_subjects" {
  principal   = "User:${confluent_service_account.schema_registry_cluster_api.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.cluster_linking_demo.resource_name}/subject=*"

  depends_on = [ 
    confluent_service_account.schema_registry_cluster_api,
    data.confluent_schema_registry_cluster.cluster_linking_demo
  ]
}

resource "confluent_role_binding" "schema_registry_developer_write_all_subjects" {
  principal   = "User:${confluent_service_account.schema_registry_cluster_api.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.cluster_linking_demo.resource_name}/subject=*"

  depends_on = [ 
    confluent_service_account.schema_registry_cluster_api,
    data.confluent_schema_registry_cluster.cluster_linking_demo
  ]
}
