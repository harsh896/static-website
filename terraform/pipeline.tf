resource "aws_codepipeline_webhook" "appPipelienWebhook" {
  name            = "KubernetesAppPipelineWebhook"
  authentication  = "GITHUB_HMAC"
  target_action   = "SourceAction"
  target_pipeline = aws_codepipeline.codepipeline.name

  authentication_configuration {
    secret_token = var.github_token
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}
resource "aws_codebuild_source_credential" "authorization" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

resource "aws_codebuild_project" "codebuild" {
  name          = "KubernetesServiceBuildProject"
  description   = "This is the Terraform generated build project"
  badge_enabled = false
  service_role  = "arn:aws:iam::828819356211:role/service-role/codeBuildServiceRole"
  
  build_timeout = 30
  queued_timeout = 180
  encryption_key = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/s3"

  artifacts {
    type = "S3"
    encryption_disabled = true
    location = aws_s3_bucket.pipeline.id
    name = "kube-Build"
    packaging = "ZIP"
    path = "kube/"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    
    environment_variable {
      name  = "REGION"
      type  = "PLAINTEXT"
      value = data.aws_region.current.name
    }

    environment_variable {
      name = "ASSUME_ROLE_ARN"
      value = "arn:aws:iam::828819356211:role/service-role/codeBuildServiceRole"
      type = "PLAINTEXT"
    }
    environment_variable {
      name = "REPOSITORY_URI"
      value = aws_ecr_repository.ecr.repository_url
      type = "PLAINTEXT"
    }
    environment_variable {
      name = "EnvironmentName"
      value = var.EnvironmentName
      type = "PLAINTEXT"
    }
    environment_variable {
      name = "APPNAME"
      value = "WEBAPP"
      type = "PLAINTEXT"
    }
    environment_variable {
      name = "EKS_CLUSTER_NAME"
      value = aws_eks_cluster.eks.id
      type = "PLAINTEXT"
    }
  }

  logs_config {
    cloudwatch_logs {
      status   = "ENABLED"
    }

    s3_logs {
      status   = "DISABLED"
      encryption_disabled = false
    }
  }
  
  source {
    type            = "GITHUB"
    location        = "https://github.com/harsh896/static-website.git"
    git_clone_depth = 1
    
    auth {
      type     = "OAUTH"
      resource = aws_codebuild_source_credential.authorization.id
    }

    git_submodules_config {
      fetch_submodules = false
    }
    buildspec = "deployment/buildspec.yml"
    report_build_status = false
    insecure_ssl = false
  }

  source_version = "master"

  # vpc_config {
  #   vpc_id = var.pipelineVpcId
  #   subnets = var.pipelineSubnets
  #   security_group_ids = var.pipelineSGId
  # }

  tags = {}
}

resource "aws_codepipeline" "codepipeline" {

  name     = "kube-service-pipeline"
  role_arn = "arn:aws:iam::828819356211:role/CodePipelineRole"

  artifact_store {
    location = aws_s3_bucket.pipeline.id
    type     = "S3"
  }

  stage {
    name = "Source"
    
    action {
      run_order = 1
      name             = "SourceAction"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        Owner      = "harsh896"
        Repo       = "static-website"
        Branch     = "master"
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    
    action {
      run_order = 1
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"
      region           = data.aws_region.current.name
      configuration = {
        ProjectName = "KubernetesServiceBuildProject"
      }
    }
  } 
}