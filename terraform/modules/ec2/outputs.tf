output "instance_id"  { value = aws_instance.this.id }
output "public_ip"    { value = aws_eip.this.public_ip }
output "public_dns"   { value = aws_eip.this.public_dns }
output "private_ip"   { value = aws_instance.this.private_ip }
