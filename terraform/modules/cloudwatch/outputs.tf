output "app_log_group_name"    { value = aws_cloudwatch_log_group.app.name }
output "system_log_group_name" { value = aws_cloudwatch_log_group.system.name }
output "dashboard_name"        { value = aws_cloudwatch_dashboard.main.dashboard_name }
