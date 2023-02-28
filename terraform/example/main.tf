terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.52"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

module "test_ecs_rds_redis_module" {
  source       = "../"
  service_name = "sign-in-service-test"

  tags = {
    Name      = "ianhundere-Sign-in-Service"
    Domain    = "Identity/MFA Team"
    Service   = "Sign-in-Service"
    Contact   = "ian.hundere@oddball.io"
    Repo      = "https://github.com/department-of-veterans-affairs/sign-in-service-infra"
    ManagedBy = "Terraform"
  }
}
