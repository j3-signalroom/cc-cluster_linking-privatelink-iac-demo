terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "cc-iac-aws_pni-isolated-vpcs-cl-example"
        }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.28.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.58.0"
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
