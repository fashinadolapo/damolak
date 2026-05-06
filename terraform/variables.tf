variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name — used as a prefix for all resources"
  type        = string
  default     = "damolak"
}

variable "environment" {
  description = "Deployment environment (dev / staging / production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "owner" {
  description = "Resource owner (for tagging)"
  type        = string
  default     = "devops-team"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into instances. Restrict to your IP in production."
  type        = string
  default     = "0.0.0.0/0"    # ← tighten in real usage
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
}

variable "app_instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t4g.micro"
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 3000
}

variable "app_version" {
  description = "Docker image tag / app version to deploy"
  type        = string
  default     = "latest"
}

# ── GitHub Actions OIDC ───────────────────────────────────────────────────────

variable "github_org" {
  description = "Your GitHub username or organisation (used to scope the OIDC trust)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}

variable "public_key_path" {
  type = string
}