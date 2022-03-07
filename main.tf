locals {
  aws_region               = "eu-west-1"
  site_name                = "food"
  profile                  = "default"
  site_domain              = "food.araines.net"
  site_prefix              = "www"
  hosted_zone_id           = "Z1BMFFD43RYRYX"
  wordpress_admin_email    = "andrew.raines@gmail.com"
  wordpress_admin_user     = "araines"
  wordpress_admin_password = "changeme"
}

terraform {
  backend "s3" {
    bucket = "araines-tfstate"
    key    = "food.araines.net/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "aws_caller_identity" "current" {}



#module "food_vpc" {
#  source = "terraform-aws-modules/vpc/aws"
#
#  name = "food"
#  cidr = "10.0.0.0/16"
#
#  azs             = ["eu-west-1a", "eu-west-1b"]
#  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
#  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
#
#  enable_nat_gateway = true
#  enable_vpn_gateway = true
#
#  tags = {
#    Terraform   = "true"
#    Environment = "dev"
#  }
#}

module "food_vpc" {
  source = "./vpc"
}

#module "food_website" {
#  source         = "TechToSpeech/serverless-static-wordpress/aws"
#  version        = "0.1.2"
#  main_vpc_id    = module.food_vpc.food_vpc_id
#  subnet_ids     = module.food_vpc.subnet_ids
#  aws_account_id = data.aws_caller_identity.current.account_id
#
#  # site_name will be used to prepend resource names - use no spaces or special characters
#  site_name                = local.site_name
#  site_domain              = local.site_domain
#  site_prefix              = local.site_prefix
#  wordpress_subdomain      = "wordpress"
#  wordpress_admin_email    = local.wordpress_admin_email
#  wordpress_admin_user     = local.wordpress_admin_user
#  wordpress_admin_password = local.wordpress_admin_password
#  hosted_zone_id           = local.hosted_zone_id
#  s3_region                = local.aws_region
#  ecs_cpu                  = 1024
#  ecs_memory               = 2048
#  cloudfront_aliases       = [local.site_domain]
#  waf_enabled              = false
#
#  # Provides the toggle to launch Wordpress container
#  launch = var.launch
#
#  ## Passing in Provider block to module is essential
#  providers = {
#    aws.ue1 = aws.ue1
#  }
#}

# Optional (but highly recommended) helper module for pull/push official Wordpress docker image to ECR

module "docker_pullpush" {
  source         = "TechToSpeech/ecr-mirror/aws"
  version        = "0.0.6"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = local.aws_region
  docker_source  = "wordpress:php7.4-apache"
  aws_profile    = "default"
  ecr_repo_name  = aws_ecr_repository.serverless_wordpress.name
  ecr_repo_tag   = "base"
  depends_on = [
    aws_ecr_repository.serverless_wordpress,
    aws_s3_object.wordpress_dockerbuild,
  ]
}


# Optional helper resources to trigger CodeBuild

resource "null_resource" "trigger_build" {
  triggers = {
    codebuild_etag = data.archive_file.code_build_package.output_md5
  }
  provisioner "local-exec" {
    command = "aws codebuild start-build --project-name ${aws_codebuild_project.wordpress_docker_build.name} --profile ${local.profile} --region ${local.aws_region}"
  }
  depends_on = [module.docker_pullpush]
}
