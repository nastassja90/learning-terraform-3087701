# outputs.tf defines the outputs for the root module. 
# Each Terraform module can have a list of inputs and outputs variables that can be used to customize 
# the module or to export values to be used by other components.

output "instance_ami" {
  value = aws_instance.blog.ami
}

output "instance_arn" {
  value = aws_instance.blog.arn
}
