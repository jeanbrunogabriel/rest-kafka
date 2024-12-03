data "aws_ami" "amazon_linux" {
 most_recent = true
 owners      = ["amazon"]

 filter {
   name   = "name"
   values = ["al2023-ami-2023.*-x86_64"]
 }
}

resource "aws_instance" "ec2" {
  tags = {
    Name = var.name
  }
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  user_data         = templatefile("${path.module}/scripts/script.sh", var.user_data_vars)
  user_data_replace_on_change  = true
  subnet_id         = var.subnet
  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids   = var.security_groups
  
}
