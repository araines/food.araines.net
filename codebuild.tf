# Define CodeBuild pipelines

data "aws_region" "current" {}

resource "aws_s3_bucket" "code_source" {
  bucket        = "${local.site_name}-build"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "code_source" {
  bucket = aws_s3_bucket.code_source.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code_source" {
  bucket = aws_s3_bucket.code_source.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "code_source" {
  bucket                  = aws_s3_bucket.code_source.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "${local.site_name}_CodeBuildServiceRole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "codebuild_role_attachment" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess" #TODO
}

data "archive_file" "code_build_package" { #TODO
  type        = "zip"
  output_path = "${path.module}/codebuild_files/wordpress_docker.zip"
  excludes    = ["wordpress_docker.zip"]
  source_dir  = "${path.module}/codebuild_files/"
  depends_on = [
    local_file.php_ini
  ]
}

resource "aws_s3_object" "wordpress_dockerbuild" { #TODO
  bucket = aws_s3_bucket.code_source.bucket
  key    = "wordpress_docker.zip"
  source = "${path.module}/codebuild_files/wordpress_docker.zip"
  etag   = data.archive_file.code_build_package.output_md5
}

resource "aws_security_group" "codebuild_security_group" {
  name        = "${local.site_name}_codebuild_sg"
  description = "Security Group for Codebuild"
  vpc_id      = module.food_vpc.food_vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "wordpress_docker_build" {
  name              = "/aws/codebuild/${local.site_name}-serverless-wordpress-docker-build"
  retention_in_days = 7
}

resource "aws_codebuild_project" "wordpress_docker_build" {
  name          = "${local.site_name}-serverless-wordpress-docker-build"
  description   = "Builds an image of wordpress in docker"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.code_source.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.serverless_wordpress.name
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.wordpress_docker_build.name
    }
  }

  source {
    type     = "S3"
    location = "${aws_s3_bucket.code_source.id}/${aws_s3_object.wordpress_dockerbuild.id}"
  }
}

resource "local_file" "php_ini" {
  content  = <<-EOT
      upload_max_filesize=64M
      post_max_size=64M
      max_execution_time=0
      max_input_vars=2000
      memory_limit=2048M
    EOT
  filename = "${path.module}/codebuild_files/php.ini"
}
