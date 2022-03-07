terraform {
  required_version = "> 0.15.1"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.ue1]
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "ue1"
  region = "us-east-1"
}
