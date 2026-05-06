# Copy to terraform.tfvars and fill in your values.
# terraform.tfvars is gitignored — never commit it.

aws_region   = "eu-central-1"
project_name = "damolak"
environment  = "production"
owner        = "Dolapo_Fashina"

# Networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
allowed_ssh_cidr     = "0.0.0.0/0"   # curl ifconfig.me

# EC2
key_pair_name     = "damolak"
app_instance_type = "t4g.micro"
app_port          = 3000
app_version       = "latest"
public_key_path   = "~/.ssh/damolak.pub"

# GitHub — used to scope the OIDC trust to your repo only
github_org  = "fashinadolapo"
github_repo = "damolak"
