locals {
  aws_region            = "eu-west-1"
  site_name             = "food"
  profile               = "default"
  site_domain           = "food.araines.net"
  site_prefix           = "www"
  hosted_zone_id        = "Z1BMFFD43RYRYX"
  wordpress_admin_email = "andrew.raines@gmail.com"
}

terraform {
  backend "s3" {
    bucket = "araines-tfstate"
    key    = "food.araines.net/terraform.tfstate"
    region = "eu-west-1"
  }
}


data "aws_caller_identity" "current" {}

module "food_vpc" {
  source = "./vpc"
}

module "food_website" {
  source         = "TechToSpeech/serverless-static-wordpress/aws"
  version        = "0.1.2"
  main_vpc_id    = module.food_vpc.food_vpc_id
  subnet_ids     = module.food_vpc.subnet_ids
  aws_account_id = data.aws_caller_identity.current.account_id

  # site_name will be used to prepend resource names - use no spaces or special characters
  site_name           = local.site_name
  site_domain         = local.site_domain
  site_prefix         = local.site_prefix
  wordpress_subdomain = "wordpress"
  hosted_zone_id      = local.hosted_zone_id
  s3_region           = local.aws_region
  ecs_cpu             = 1024
  ecs_memory          = 2048
  cloudfront_aliases  = ["food.araines.net"]
  waf_enabled         = false

  # Provides the toggle to launch Wordpress container
  launch = var.launch

  ## Passing in Provider block to module is essential
  providers = {
    aws.ue1 = aws.ue1
  }
}

# Optional (but highly recommended) helper module for pull/push official Wordpress docker image to ECR

module "docker_pullpush" {
  source         = "TechToSpeech/ecr-mirror/aws"
  version        = "0.0.6"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = local.aws_region
  docker_source  = "wordpress:php7.4-apache"
  aws_profile    = "default"
  ecr_repo_name  = module.food_website.wordpress_ecr_repository
  ecr_repo_tag   = "base"
  depends_on     = [module.food_website]
}


# Optional helper resources to trigger CodeBuild

resource "null_resource" "trigger_build" {
  triggers = {
    codebuild_etag = module.food_website.codebuild_package_etag
  }
  provisioner "local-exec" {
    command = "aws codebuild start-build --project-name ${module.food_website.codebuild_project_name} --profile ${local.profile} --region ${local.aws_region}"
  }
  depends_on = [
    module.food_website, module.docker_pullpush
  ]
}
