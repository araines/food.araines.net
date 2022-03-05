# Serverless aurora MySQL database for WordPress
locals {
  rds_cluster_id = "${local.site_name}-serverless-wordpress"
}

resource "random_password" "serverless_wordpress_password" {
  length           = 16
  special          = true
  override_special = "!#%&*()-_=+[]<>"
}

resource "aws_security_group" "aurora_serverless_group" {
  name        = "${local.site_domain}_aurora_mysql_sg"
  description = "Security Group for WordPress Serverless Aurora"
  vpc_id      = module.food_vpc.food_vpc_id
}

resource "aws_security_group_rule" "aurora_sg_ingress_3306" {
  description              = "Ingress for MySQL Aurora for WordPress"
  security_group_id        = aws_security_group.aurora_serverless_group.id
  source_security_group_id = aws_security_group.wordpress_security_group.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "TCP"
}

resource "aws_db_subnet_group" "main_vpc" {
  name       = "${local.site_name}_main"
  subnet_ids = module.food_vpc.subnet_ids
}

resource "random_id" "rds_snapshot" {
  byte_length = 8
}

resource "aws_cloudwatch_log_group" "serverless_wordpress" {
  name              = "/aws/rds/cluster/${local.rds_cluster_id}/error"
  retention_in_days = 7
}

resource "aws_rds_cluster" "serverless_wordpress" {
  cluster_identifier     = local.rds_cluster_id
  engine                 = "aurora-mysql"
  engine_mode            = "serverless"
  database_name          = "wordpress"
  master_username        = "wp_master" #TODO
  master_password        = random_password.serverless_wordpress_password.result
  vpc_security_group_ids = [aws_security_group.aurora_serverless_group.id]
  db_subnet_group_name   = aws_db_subnet_group.main_vpc.name

  backup_retention_period             = 5
  enable_http_endpoint                = false #TODO
  iam_database_authentication_enabled = false
  storage_encrypted                   = true
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 1
    min_capacity             = 1
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.rds_cluster_id}-${random_id.rds_snapshot.dec}"
  depends_on = [
    aws_cloudwatch_log_group.serverless_wordpress
  ]
}
