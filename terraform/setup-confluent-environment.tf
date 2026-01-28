resource "confluent_environment" "non_prod" {
  display_name = "non-prod"

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_private_link_attachment" "non_prod" {
  cloud        = "AWS"
  region       = var.aws_region
  display_name = "${confluent_environment.non_prod.display_name}-aws-platt"
  
  environment {
    id = confluent_environment.non_prod.id
  }

  depends_on = [
    confluent_environment.non_prod
  ]
}
