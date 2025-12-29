terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "cc-sandbox-cluster-sharing"
        }
  }

  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.27.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.57.0"
        }
    }
}
