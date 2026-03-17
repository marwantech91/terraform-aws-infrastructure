/**
 * Development Environment
 *
 * Cost-optimized: single NAT, smaller instances, relaxed retention.
 * Estimated monthly cost: ~$400
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
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = "myapp"
    }
  }
}

locals {
  name = "myapp-dev"
  azs  = ["us-east-1a", "us-east-1b"]
  tags = { Environment = "dev", Project = "myapp" }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr               = "10.10.0.0/16"
  azs                = local.azs
  public_subnets     = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets    = ["10.10.11.0/24", "10.10.12.0/24"]
  database_subnets   = ["10.10.21.0/24", "10.10.22.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true # Cost savings
  enable_flow_logs   = false
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks"

  name                = local.name
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  kubernetes_version  = "1.29"
  node_instance_types = ["t3.medium"]
  node_min_size       = 1
  node_max_size       = 5
  node_desired_size   = 2
  fargate_namespaces  = ["default"]
  tags                = local.tags
}

module "rds" {
  source = "../../modules/rds"

  name                       = local.name
  vpc_id                     = module.vpc.vpc_id
  database_subnet_group_name = module.vpc.database_subnet_group_name
  allowed_security_groups    = [module.eks.cluster_security_group_id]
  instance_class             = "db.t4g.medium"
  instance_count             = 1
  database_name              = "app_dev"
  backup_retention_period    = 1
  deletion_protection        = false
  tags                       = local.tags
}
