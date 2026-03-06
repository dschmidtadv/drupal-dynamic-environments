# Security Group for Aurora
resource "aws_security_group" "aurora" {
  name_prefix = "${var.project_name}-aurora-"
  description = "Security group for Aurora Serverless cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS hosts"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_hosts.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-aurora"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name_prefix = "${var.project_name}-aurora-"
  description = "Subnet group for Aurora Serverless cluster"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${var.project_name}-aurora"
  }
}

# Generate random password for Aurora master user
resource "random_password" "aurora_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store Aurora master password in Secrets Manager
resource "aws_secretsmanager_secret" "aurora_master_password" {
  name_prefix             = "${var.project_name}-aurora-master-"
  description             = "Aurora master password for Drupal"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.arn

  tags = {
    Name = "${var.project_name}-aurora-master-password"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_master_password" {
  secret_id = aws_secretsmanager_secret.aurora_master_password.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.aurora_master.result
    engine   = "mysql"
    host     = aws_rds_cluster.aurora.endpoint
    port     = 3306
    dbname   = "drupal"
  })
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier     = "${var.project_name}-aurora"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  engine_version         = var.aurora_engine_version
  database_name          = "drupal"
  master_username        = var.db_master_username
  master_password        = random_password.aurora_master.result
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  storage_encrypted      = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  backup_retention_period   = 7
  preferred_backup_window   = "03:00-04:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = "${var.project_name}-aurora"
  }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# Aurora Serverless v2 Instance
resource "aws_rds_cluster_instance" "aurora" {
  identifier         = "${var.project_name}-aurora-instance"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  tags = {
    Name = "${var.project_name}-aurora-instance"
  }
}

