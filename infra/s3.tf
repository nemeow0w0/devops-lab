resource "aws_s3_bucket" "backup" {
  bucket_prefix = "tinyshop-backup-"
  force_destroy = true
}



resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "expire-old-backup"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 7
    }
  }
}


output "backup_bucket" {
  value = aws_s3_bucket.backup.bucket
}