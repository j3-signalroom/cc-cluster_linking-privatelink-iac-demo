terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "cc-cluster-linking-privatelink-iac-demo"
        }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.28.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.57.0"
        }
        time = {
            source  = "hashicorp/time"
            version = "~> 0.13.1"
        }
    }
}
