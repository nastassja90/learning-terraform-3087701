data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

# create a default VPC
data "aws_vpc" "default" {
  default = true
}

# Import the security group module
module "blog_security_group" {
  source = "./modules/security-group"
  
  security_group_name = "blog"
  vpc_id             = data.aws_vpc.default.id
  allowed_ingress_cidr_blocks = ["0.0.0.0/0"]
  allowed_egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name      = "BlogSecurityGroup"
    Terraform = "true"
  }
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  # Associate the instance with the security group from the module
  vpc_security_group_ids = [module.blog_security_group.security_group_id]

  tags = {
    Name = "HelloWorld"
  }
}
