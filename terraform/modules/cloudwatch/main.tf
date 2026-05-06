# ── Log Groups ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = 30

  tags = { Name = "${var.project_name}-${var.environment}-app-logs" }
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project_name}/${var.environment}/system"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-${var.environment}-system-logs" }
}

# ── Dashboard ─────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "EC2 CPU Utilization"
          region  = var.aws_region
          metrics = [["AWS/EC2", "CPUUtilization", { stat = "Average", period = 300 }]]
          view    = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "Memory Used %"
          region  = var.aws_region
          metrics = [["CWAgent", "mem_used_percent", { stat = "Average", period = 300 }]]
          view    = "timeSeries"
        }
      },
      {
        type = "log"
        properties = {
          title  = "Application Logs (latest)"
          region = var.aws_region
          query  = "SOURCE '/${var.project_name}/${var.environment}/app' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "EC2 Network In/Out"
          region  = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn",  { stat = "Sum", period = 300 }],
            ["AWS/EC2", "NetworkOut", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}

# ── Alarms ────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU utilization exceeded 80% for 4 minutes"
  treat_missing_data  = "notBreaching"

  tags = { Name = "${var.project_name}-${var.environment}-high-cpu-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EC2 memory usage exceeded 85%"
  treat_missing_data  = "notBreaching"

  tags = { Name = "${var.project_name}-${var.environment}-high-memory-alarm" }
}
