provider "aws" {
  region = "us-gov-west-1"

  default_tags {
    tags = var.tags
  }
}
