/**
 * RDS Aurora PostgreSQL Module
 *
 * Multi-AZ Aurora cluster with:
 * - Encryption at rest (KMS)
 * - Automated backups with PITR
 * - Performance Insights
 * - Enhanced monitoring
 * - Security group restricting access to VPC
 */

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_group_name" {
  type = string
}

variable "allowed_security_groups" {
  type        = list(string)
  description = "Security groups allowed to connect to the database"
}

variable "engine_version" {
  type    = string
  default = "15.4"
}

variable "instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "database_name" {
  type    = string
  default = "app"
}

variable "master_username" {
  type    = string
  default = "postgres"
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

# --- KMS Key ---

resource "aws_kms_key" "rds" {
  description             = "RDS encryption key for ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

# --- Security Group ---

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-rds-sg"
  })
}

resource "aws_security_group_rule" "rds_ingress" {
  count = length(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.rds.id
  description              = "PostgreSQL from allowed SG"
}

# --- Password from Secrets Manager ---

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.name}/rds/master-password"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "aurora-postgresql"
    host     = aws_rds_cluster.main.endpoint
    port     = 5432
    dbname   = var.database_name
  })
}

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:,.<>?"
}

# --- Aurora Cluster ---

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.name}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = random_password.master.result

  db_subnet_group_name   = var.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.name}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.tags
}

resource "aws_rds_cluster_instance" "instances" {
  count = var.instance_count

  identifier         = "${var.name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = var.tags
}

# --- Enhanced Monitoring ---

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}

# --- Outputs ---

output "cluster_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.main.reader_endpoint
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
