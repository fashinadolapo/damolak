# ── AMI: Latest Amazon Linux 2023 ────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── User Data: App Server Bootstrap ──────────────────────────────────────────

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

    echo "=== App Server Bootstrap ==="

    yum update -y
    yum install -y docker awscli jq wget

    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # ── CloudWatch Agent ───────────────────────────────────────────────────
    yum install -y amazon-cloudwatch-agent

    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
    {
      "agent": { "metrics_collection_interval": 60 },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/user-data.log",
                "log_group_name": "${log_group_name}",
                "log_stream_name": "{instance_id}/bootstrap"
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
          "cpu":  { "measurement": ["cpu_usage_idle", "cpu_usage_user"], "metrics_collection_interval": 60 },
          "mem":  { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
          "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 60, "resources": ["*"] }
        }
      }
    }
    CWCONFIG

    systemctl enable amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

    # ── Deployment script (GitHub Actions copies an updated version on each deploy) ──
    mkdir -p /opt/app /var/log/app
    chown ec2-user:ec2-user /opt/app /var/log/app

    echo "=== Bootstrap Complete ==="
  EOF
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens                 = "required"   # IMDSv2
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app"
  }
}

# ── Elastic IP ────────────────────────────────────────────────────────────────

resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-app-eip"
  }
}
