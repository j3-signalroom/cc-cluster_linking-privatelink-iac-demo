resource "confluent_environment" "cluster_linking_demo" {
  display_name = "cluster_linking_demo"

  stream_governance {
    package = "ESSENTIALS"
  }
}