# Production AWS Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-1.7+-844FBA?style=flat-square&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Production-FF9900?style=flat-square&logo=amazonaws)

Production-grade AWS infrastructure as code using Terraform modules. Multi-environment (dev/staging/prod) with VPC, EKS, RDS, ElastiCache, S3, CloudFront, and WAF.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CloudFront + WAF                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     Application Load Balancer                │
│                        (Public Subnets)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     EKS Cluster (3 AZs)                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │ App Pods    │ │ API Pods    │ │ Worker Pods         │   │
│  │ (Fargate)   │ │ (Fargate)   │ │ (Managed Nodes)     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
│                     (Private Subnets)                        │
└───────┬────────────────┬─────────────────┬──────────────────┘
        │                │                 │
┌───────▼────┐  ┌────────▼─────┐  ┌───────▼────────┐
│  RDS Aurora │  │ ElastiCache  │  │   S3 Buckets   │
│  (Multi-AZ) │  │   (Redis)    │  │  (Encrypted)   │
│  PostgreSQL │  │   Cluster    │  │                │
└────────────┘  └──────────────┘  └────────────────┘
```

## Module Structure

| Module | Description |
|--------|-------------|
| `vpc` | VPC with public/private/database subnets across 3 AZs |
| `eks` | EKS cluster with Fargate profiles and managed node groups |
| `rds` | Aurora PostgreSQL with Multi-AZ, automated backups |
| `elasticache` | Redis cluster with encryption and failover |
| `s3` | Encrypted S3 buckets with lifecycle policies |
| `cloudfront` | CDN distribution with custom origin configs |
| `waf` | Web Application Firewall with OWASP rules |

## Environments

```
environments/
├── dev/          # Single-AZ, smaller instances, relaxed security
├── staging/      # Mirrors production topology, smaller scale
└── production/   # Multi-AZ, autoscaling, full security hardening
```

## Usage

```bash
cd environments/production
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Design Decisions

- **Fargate for stateless workloads**: No node management, pay-per-pod
- **Managed nodes for stateful workers**: GPU/high-memory jobs need EC2
- **Aurora over vanilla RDS**: Built-in replication, fast failover
- **Private subnets for everything**: Only ALB and NAT Gateway are public
- **WAF at CloudFront edge**: Block threats before they reach the VPC

## License

MIT
