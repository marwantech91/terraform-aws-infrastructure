/**
 * S3 Module
 *
 * Creates an S3 bucket with:
 * - Server-side encryption (AES-256 or KMS)
 * - Versioning
 * - Lifecycle rules for cost optimization
 * - Public access blocking
 * - Optional CORS configuration
 */

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "enable_versioning" {
  type        = bool
  default     = true
  description = "Enable bucket versioning"
}

variable "encryption_type" {
  type        = string
  default     = "AES256"
  description = "Encryption type: AES256 or aws:kms"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_type)
    error_message = "encryption_type must be AES256 or aws:kms"
  }
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key ARN (required when encryption_type is aws:kms)"
}

variable "lifecycle_rules" {
  type = list(object({
    id                  = string
    prefix              = string
    transition_days     = number
    transition_class    = string
    expiration_days     = optional(number)
    noncurrent_days     = optional(number)
  }))
  default     = []
  description = "Lifecycle rules for cost optimization"
}

variable "cors_rules" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    max_age_seconds = optional(number, 3600)
  }))
  default     = []
  description = "CORS configuration rules"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow bucket deletion with objects inside"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags"
}

# --- Bucket ---

resource "aws_s3_bucket" "main" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

# --- Versioning ---

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# --- Encryption ---

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type
      kms_master_key_id = var.encryption_type == "aws:kms" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.encryption_type == "aws:kms"
  }
}

# --- Public Access Block ---

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle Rules ---

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      filter {
        prefix = rule.value.prefix
      }

      transition {
        days          = rule.value.transition_days
        storage_class = rule.value.transition_class
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_days
        }
      }
    }
  }
}

# --- CORS ---

resource "aws_s3_bucket_cors_configuration" "main" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# --- Outputs ---

output "bucket_id" {
  value = aws_s3_bucket.main.id
}

output "bucket_arn" {
  value = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  value = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.main.bucket_regional_domain_name
}
