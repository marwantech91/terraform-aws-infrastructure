# Terraform native test for S3 module variables validation

variables {
  bucket_name       = "test-bucket-validation"
  enable_versioning = true
  encryption_type   = "AES256"
  force_destroy     = true
  tags              = { Environment = "test" }
}

run "s3_bucket_name_is_set" {
  command = plan

  module {
    source = "../modules/s3"
  }

  assert {
    condition     = aws_s3_bucket.main.bucket == "test-bucket-validation"
    error_message = "Bucket name should match input variable"
  }
}

run "s3_versioning_enabled" {
  command = plan

  module {
    source = "../modules/s3"
  }

  assert {
    condition     = aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning should be enabled"
  }
}

run "s3_public_access_blocked" {
  command = plan

  module {
    source = "../modules/s3"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_acls == true
    error_message = "Public ACLs should be blocked"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_policy == true
    error_message = "Public policy should be blocked"
  }
}
