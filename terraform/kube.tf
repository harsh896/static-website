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



data "aws_subnet_ids" "subnetIds" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "subnets" {
  for_each = data.aws_subnet_ids.subnetIds.ids
  id       = each.value
}

# output "subnet_cidr_blocks" {
#   value = [for s in data.aws_subnet.subnets : s.id]
# }


resource "aws_ecr_repository" "ecr" {
  name = "kubernetes"
}
resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Rentention upto 15 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 15
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

resource "aws_ecr_repository_policy" "repo_policy" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1598451708753",
      "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecr:ListTagsForResource"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
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



resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "node_tuto"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [for s in data.aws_subnet.subnets : s.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

