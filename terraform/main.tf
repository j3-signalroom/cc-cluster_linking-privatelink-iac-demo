terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "iac-cc-aws-privatelink-cluster-linking-example"
        }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.29.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.59.0"
        }
        time = {
            source  = "hashicorp/time"
            version = "~> 0.13.1"
        }
        tfe = {
            source = "hashicorp/tfe"
            version = "~> 0.73.0"
        }
    }
}
