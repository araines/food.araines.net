# Lambda function that allows launching WordPress via the web

# Create a zip of the dir to get a hash so we know
# when to re-run npm ci
data "archive_file" "launcher_npm_trigger" {
  type        = "zip"
  source_dir  = "launcher"
  output_path = "launcher.zip"
}

resource "null_resource" "launcher_npm" {
  provisioner "local-exec" {
    working_dir = "launcher"
    command     = "npm ci"
  }

  triggers = {
    src_hash = data.archive_file.launcher_npm_trigger.output_sha
  }
}

data "archive_file" "launcher" {
  type        = "zip"
  source_dir  = "launcher"
  output_path = "launcher.zip"
  depends_on  = [null_resource.launcher_npm]
}

resource "aws_lambda_function" "launcher" {
  filename         = "launcher.zip"
  function_name    = "${local.site_name}-launcher"
  role             = aws_iam_role.launcher.arn
  handler          = "launcher.handler"
  source_code_hash = data.archive_file.launcher.output_base64sha256
  runtime          = "nodejs14.x"

  environment {
    variables = {
      region  = local.aws_region
      cluster = aws_ecs_cluster.wordpress_cluster.name
      service = aws_ecs_service.wordpress_service.id
    }
  }
}

data "aws_iam_policy_document" "launcher_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "launcher" {
  name               = "${local.site_name}-launcherRole"
  assume_role_policy = data.aws_iam_policy_document.launcher_role.json
}

resource "aws_cloudwatch_log_group" "launcher" {
  name              = "/aws/lambda/${local.site_name}-launcher"
  retention_in_days = 7
}

data "aws_iam_policy_document" "launcher_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_policy" "launcher_logging" {
  name   = "${local.site_name}_launcher_logging"
  policy = data.aws_iam_policy_document.launcher_logging.json
}

resource "aws_iam_role_policy_attachment" "launcher_logs" {
  role       = aws_iam_role.launcher.name
  policy_arn = aws_iam_policy.launcher_logging.arn
}

data "aws_iam_policy_document" "launcher_ecs" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService"
    ]
    resources = [
      aws_ecs_service.wordpress_service.id
    ]
  }
}

resource "aws_iam_policy" "launcher_ecs" {
  name   = "${local.site_name}_launcher_ecs"
  policy = data.aws_iam_policy_document.launcher_ecs.json
}

resource "aws_iam_role_policy_attachment" "launcher_ecs" {
  role       = aws_iam_role.launcher.name
  policy_arn = aws_iam_policy.launcher_ecs.arn
}
