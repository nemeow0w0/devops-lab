# Trust policy Only EC can use this role
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}



resource "aws_iam_role" "backup" {
  name_prefix        = "tinyshop-backup-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}


# Permission policy: only put file
data "aws_iam_policy_document" "backup_put" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.backup.arn}/backups/*"]
  }
}


resource "aws_iam_role_policy" "backup_put" {
  name   = "put-backups-only"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.backup_put.json
}


# Instance profile: the "lanyard"
resource "aws_iam_instance_profile" "backup" {
  name_prefix = "tinyshop-backup-"
  role        = aws_iam_role.backup.name
}