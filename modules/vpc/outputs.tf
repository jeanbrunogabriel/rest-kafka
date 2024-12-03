output "id" {
  value = aws_vpc.vpc.id
}
 output "subnet" {
  value = {
    for k,v in aws_subnet.subnet : k => v.id
  }
}

output "security_groups" {
  value = {
    for k,v in aws_security_group.sg : k => v
  }
}
