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

resource "random_password" "launch_password" {
  length = 40
  special = false
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
      password = random_password.launch_password.result
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

resource "aws_apigatewayv2_api" "launcher" {
  name          = "${local.site_name}-launcher"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "launcher" {
  api_id      = aws_apigatewayv2_api.launcher.id
  name        = "${local.site_name}-launcher"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.launcher_api_gw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "launcher" {
  api_id             = aws_apigatewayv2_api.launcher.id
  integration_uri    = aws_lambda_function.launcher.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "launcher" {
  api_id    = aws_apigatewayv2_api.launcher.id
  route_key = "POST /launch"
  target    = "integrations/${aws_apigatewayv2_integration.launcher.id}"
}

resource "aws_cloudwatch_log_group" "launcher_api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.launcher.name}"
  retention_in_days = 7
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.launcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.launcher.execution_arn}/*/*"
}
# TODO: Create an API Gateway to trigger the lambda
# Create a Route 53 record for the API Gateway
# Enhance Lambda to include two pieces of functionality:
# 1. Serve a basic webpage with a password box + launch/stop buttons
# 2. A launch URL which checks the password + launches if desired
# 3. A launch URL which checks the password + shuts down if desired
