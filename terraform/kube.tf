data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

#-----------------------------------Code Pipeline S3 bucket for artifact store------------------------------------------
resource "aws_s3_bucket" "pipeline" {
  bucket_prefix = "kubernetes-codepipeline-bucket-"
  force_destroy = true
}
resource "aws_s3_bucket_policy" "CodePipelineArtifactStore" {
  bucket = aws_s3_bucket.pipeline.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnEncryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.pipeline.arn}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyInsecureConnections",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "${aws_s3_bucket.pipeline.arn}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_ecr_repository" "ecr" {
  name = "kubernetes"
}

resource "aws_eks_cluster" "eks" {
  name     = "kubernetes-cluster"
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = [for s in data.aws_subnet.subnets : s.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy
  ]
}

data "aws_subnet_ids" "subnetIds" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "subnets" {
  for_each = data.aws_subnet_ids.subnetIds.ids
  id       = each.value
}

output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnet.subnets : s.id]
}