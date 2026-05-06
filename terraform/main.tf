terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — use S3 backend in production
  # Uncomment and fill in bucket/key/region after creating the S3 bucket
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "devops-challenge/terraform.tfstate"
  #   region         = var.aws_region
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region
  profile = "agrovesto-dev"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# ── Data Sources ──────────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ── Modules ───────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  app_port         = var.app_port
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  account_id   = data.aws_caller_identity.current.account_id
  github_org   = var.github_org
  github_repo  = var.github_repo
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "ec2_app" {
  source = "./modules/ec2"

  project_name         = var.project_name
  environment          = var.environment
  instance_type        = var.app_instance_type
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.security_groups.app_sg_id]
  key_name             = var.key_pair_name
  public_key_path      = var.public_key_path
  iam_instance_profile = module.iam.ec2_instance_profile_name
  ecr_repository_url   = module.ecr.repository_url
  aws_region           = var.aws_region
  app_port             = var.app_port
  app_version          = var.app_version
  log_group_name       = module.cloudwatch.app_log_group_name
}
