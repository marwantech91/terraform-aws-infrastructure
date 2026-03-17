/**
 * Production Environment
 *
 * Multi-AZ, autoscaling, full security hardening.
 * Estimated monthly cost: ~$2,500 (EKS + RDS + NAT + ElastiCache)
 */

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "myapp"
}

locals {
  name = "${var.project_name}-prod"
  azs  = ["${var.region}a", "${var.region}b", "${var.region}c"]

  tags = {
    Environment = "production"
    Project     = var.project_name
  }
}

# --- VPC ---

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr               = "10.0.0.0/16"
  azs                = local.azs
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnets   = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = false # One per AZ for HA
  enable_flow_logs   = true
  tags               = local.tags
}

# --- EKS ---

module "eks" {
  source = "../../modules/eks"

  name                = local.name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  kubernetes_version  = "1.29"
  node_instance_types = ["t3.xlarge"]
  node_min_size       = 3
  node_max_size       = 20
  node_desired_size   = 5
  fargate_namespaces  = ["default", "kube-system", "monitoring"]
  tags                = local.tags
}

# --- RDS ---

module "rds" {
  source = "../../modules/rds"

  name                       = local.name
  vpc_id                     = module.vpc.vpc_id
  database_subnet_group_name = module.vpc.database_subnet_group_name
  allowed_security_groups    = [module.eks.cluster_security_group_id]
  engine_version             = "15.4"
  instance_class             = "db.r6g.xlarge"
  instance_count             = 2 # Writer + Reader
  database_name              = "app_production"
  backup_retention_period    = 30
  deletion_protection        = true
  tags                       = local.tags
}

# --- Outputs ---

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value     = module.rds.cluster_endpoint
  sensitive = true
}

output "rds_secret_arn" {
  value = module.rds.secret_arn
}
