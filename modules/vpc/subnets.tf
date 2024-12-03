resource "aws_subnet" "subnet" {
  for_each   = var.subnets
  vpc_id     = aws_vpc.vpc.id
  cidr_block = each.value.cidr

  tags = {
    Name = each.key
  }
}
