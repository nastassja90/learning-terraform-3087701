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

# Import and configure the VPC module from the Terraform Registry to create a VPC with public subnets
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# Import the security group module
module "blog_security_group" {
  source = "./modules/security-group"
  
  security_group_name = "blog"
  # Associate the security group with the VPC created from the VPC module
  vpc_id             = module.blog_vpc.vpc_id
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
  # Associate the instance with the VPC subnet created from the VPC module
  subnet_id              = module.blog_vpc.public_subnets[0]
  # Associate the instance with the security group from the module
  vpc_security_group_ids = [module.blog_security_group.security_group_id]

  tags = {
    Name = "HelloWorld"
  }
}
