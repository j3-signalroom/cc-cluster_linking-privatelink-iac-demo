# Wait for DNS propagation
resource "time_sleep" "wait_for_stream_governance" {
  depends_on = [
    confluent_environment.sandbox
  ]
  
  create_duration = "1m"
}

# Config the environment's schema registry
data "confluent_schema_registry_cluster" "sandbox_src" {
  environment {
    id = confluent_environment.sandbox.id
  }

  depends_on = [
    time_sleep.wait_for_stream_governance
  ]
}

# Create the Service Account for the Kafka Cluster API
resource "confluent_service_account" "sandbox_src_api" {
    display_name = "sandbox_src_api"
    description  = "Sandbox Cluster Sharing Schema Registry Cluster API Service Account"
}

# Create the Environment API Key Pairs, rotate them in accordance to a time schedule, and provide the current
# acitve API Key Pair to use
module "sandbox_src_api_key_rotation" {
    
    source  = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

    # Required Input(s)
    owner = {
        id          = confluent_service_account.sandbox_src_api.id
        api_version = confluent_service_account.sandbox_src_api.api_version
        kind        = confluent_service_account.sandbox_src_api.kind
    }

    resource = {
        id          = data.confluent_schema_registry_cluster.sandbox_src.id
        api_version = data.confluent_schema_registry_cluster.sandbox_src.api_version
        kind        = data.confluent_schema_registry_cluster.sandbox_src.kind

        environment = {
            id = confluent_environment.sandbox.id
        }
    }
    
    # Optional Input(s)
    key_display_name = "Confluent Schema Registry Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
    number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
    day_count = var.day_count
}

resource "confluent_role_binding" "schema_registry_developer_read_all_subjects" {
  principal   = "User:${confluent_service_account.sandbox_src_api.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.sandbox_src.resource_name}/subject=*"

  depends_on = [ 
    confluent_service_account.sandbox_src_api,
    data.confluent_schema_registry_cluster.sandbox_src
  ]
}

resource "confluent_role_binding" "schema_registry_developer_write_all_subjects" {
  principal   = "User:${confluent_service_account.sandbox_src_api.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.sandbox_src.resource_name}/subject=*"

  depends_on = [ 
    confluent_service_account.sandbox_src_api,
    data.confluent_schema_registry_cluster.sandbox_src
  ]
}
