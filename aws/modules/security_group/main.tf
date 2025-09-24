# create a security group under the default VPC
resource "aws_security_group" "blog" {
  name = var.security_group_name
  tags = var.tags
  # Associate the security group with the default VPC
  vpc_id = var.vpc_id
}

# define security group rules to associate with the security group we've just created.
# the first rule "blog_http_in", allows inbound HTTP traffic on port 80 from any IP address (0.0.0.0/0)
resource "aws_security_group_rule" "blog_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.allowed_ingress_cidr_blocks
  # Add the rule to the security group we've just created
  security_group_id = aws_security_group.blog.id
}

# the second rule "blog_https_in", allows inbound HTTPS traffic on port 443 from any IP address (0.0.0.0/0)
resource "aws_security_group_rule" "blog_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.allowed_ingress_cidr_blocks
  # Add the rule to the security group we've just created
  security_group_id = aws_security_group.blog.id
}

# the third rule "blog_everything_out", allows all outbound traffic to any IP address (0.0.0.0/0)
resource "aws_security_group_rule" "blog_everything_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = var.allowed_egress_cidr_blocks
  # Add the rule to the security group we've just created
  security_group_id = aws_security_group.blog.id
}