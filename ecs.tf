# ECS for running the dynamic WordPress site

resource "aws_efs_file_system" "wordpress_persistent" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
}

data "aws_iam_policy_document" "wordpress_bucket_access" {
  statement {
    actions   = ["s3:ListBucket"]
    effect    = "Allow"
    resources = [aws_s3_bucket.website.arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
  statement {
    actions   = ["ec2:DescribeNetworkInterfaces"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${local.hosted_zone_id}"]
  }
}

resource "aws_iam_policy" "wordpress_bucket_access" {
  name        = "${local.site_name}_WordPressBucketAccess"
  description = "Policy allowing WordPress access to static site bucket"
  policy      = data.aws_iam_policy_document.wordpress_bucket_access.json
}

resource "aws_iam_role_policy_attachment" "wordpress_bucket_access" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = aws_iam_policy.wordpress_bucket_access.arn
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "wordpress_task" {
  name               = "${local.site_name}_WordPressTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_ecs" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_cloudwatch" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_efs_access_point" "wordpress_efs" {
  file_system_id = aws_efs_file_system.wordpress_persistent.id
}

resource "aws_security_group" "efs_security_group" {
  name        = "${local.site_name}_efs_sg"
  description = "Security Group for Wordpress"
  vpc_id      = module.food_vpc.food_vpc_id
}

resource "aws_security_group_rule" "efs_ingress" {
  description              = "Ingress for EFS mount for WordPress"
  security_group_id        = aws_security_group.efs_security_group.id
  source_security_group_id = aws_security_group.wordpress_security_group.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
}

# TODO: Find a better way to do this so we don't have to mount twice
resource "aws_efs_mount_target" "wordpress_efs_a" {
  file_system_id  = aws_efs_file_system.wordpress_persistent.id
  subnet_id       = module.food_vpc.subnet_id_a
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_efs_mount_target" "wordpress_efs_b" {
  file_system_id  = aws_efs_file_system.wordpress_persistent.id
  subnet_id       = module.food_vpc.subnet_id_b
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_cloudwatch_log_group" "wordpress_container" {
  name              = "/aws/ecs/${local.site_name}-serverless-wordpress-container" #TODO
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "wordpress_container" {
  family = "${local.site_name}_wordpress"
  container_definitions = templatefile("${path.module}/wordpress-task.tftpl", {
    db_host                  = aws_rds_cluster.serverless_wordpress.endpoint,
    db_user                  = aws_rds_cluster.serverless_wordpress.master_username,
    db_password              = random_password.serverless_wordpress_password.result,
    db_name                  = aws_rds_cluster.serverless_wordpress.database_name,
    wordpress_image          = "${aws_ecr_repository.serverless_wordpress.repository_url}:latest",
    wp_dest                  = "https://${local.site_domain}",
    wp_region                = local.aws_region,
    wp_bucket                = aws_s3_bucket.website.id,
    container_dns            = "wordpress.${local.site_domain}",
    container_dns_zone       = local.hosted_zone_id,
    container_cpu            = 1024,
    container_memory         = 2048,
    efs_source_volume        = "${local.site_name}_wordpress_persistent"
    wordpress_admin_user     = local.wordpress_admin_user
    wordpress_admin_password = local.wordpress_admin_password
    wordpress_admin_email    = local.wordpress_admin_email
    site_name                = local.site_name
  })

  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.wordpress_task.arn
  task_role_arn            = aws_iam_role.wordpress_task.arn

  volume {
    name = "${local.site_name}_wordpress_persistent"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wordpress_persistent.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress_efs.id
      }
    }
  }
  tags = {
    "Name" = "${local.site_name}_WordpressECS"
  }
  depends_on = [
    aws_efs_file_system.wordpress_persistent
  ]
}

resource "aws_security_group" "wordpress_security_group" {
  name        = "${local.site_name}_wordpress_sg"
  description = "security group for wordpress"
  vpc_id      = module.food_vpc.food_vpc_id
}

resource "aws_security_group_rule" "wordpress_sg_ingress_80" {
  description       = "Allow ingress from world to Wordpress container"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_2049" {
  description              = "Egress to EFS mount from Wordpress container"
  security_group_id        = aws_security_group.wordpress_security_group.id
  source_security_group_id = aws_security_group.efs_security_group.id
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_80" {
  description       = "Egress from Wordpress container to world on HTTP"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_443" {
  description       = "Egress from Wordpress container to world on HTTPS"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_3306" {
  description              = "Egress from Wordpress container to Aurora Database"
  security_group_id        = aws_security_group.wordpress_security_group.id
  source_security_group_id = aws_security_group.aurora_serverless_group.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "TCP"
}

resource "aws_ecs_service" "wordpress_service" {
  name            = "${local.site_name}_wordpress"
  task_definition = "${aws_ecs_task_definition.wordpress_container.family}:${aws_ecs_task_definition.wordpress_container.revision}"
  cluster         = aws_ecs_cluster.wordpress_cluster.arn
  desired_count   = var.launch
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = "100"
    base              = "1"
  }
  propagate_tags = "SERVICE"
  network_configuration {
    subnets          = module.food_vpc.subnet_ids
    security_groups  = [aws_security_group.wordpress_security_group.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_cluster" "wordpress_cluster" {
  name = "${local.site_name}_wordpress"
}

resource "aws_ecs_cluster_capacity_providers" "wordpress_cluster" {
  cluster_name       = aws_ecs_cluster.wordpress_cluster.name
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}
