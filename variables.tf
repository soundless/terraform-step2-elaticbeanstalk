variable "name_prefix" {
  default = "glxmanager-terraform"
}

variable "vpc_id" {
  default = "vpc-d9122cbe"
  description = "ID of the VPC to use"
}

variable "vpc_cidr" {
  default = "172.31.0.0/16"
  description = "Internal IP range, allowed to ssh to instances"
}

variable "private_subnet_one" {
  default = "subnet-c7de1e9c"
  description = "ID of first subnet for EC2-instances"
}
variable "private_subnet_two" {
  default = "subnet-ce5a38ab"
  description = "ID of second subnet for EC2-instances"
}

variable "subnet_one" {
  default = "subnet-c7de1e9c"
  description = "ID of first subnet for Load balancer"
}
variable "subnet_two" {
default = "subnet-ce5a38ab"
  description = "ID of second subnet for Load balancer"
}

variable "ssh_key" {
  default = "htian-office"
  description = "ID of key pair that will be granted SSH access to the servers"
}

variable "healthcheck_location" {
  default = ""
  description = "Location for Load balancer to check for response to see if instances in autoscaling group are healthy"
}

variable "instance_type" {
  default = "t2.micro"
  description = "Which AWS instance type (e.g. t2.micro) to start up ec2-nodes on"
}

variable "loadbalancing_desired_nodes" {
  default = 2
  description = "Desired amount of nodes in autoscaling group"
}  

variable "loadbalancing_min_nodes" {
  default = 2
  description = "Minimum amount of nodes in autoscaling group"
}
variable "loadbalancing_max_nodes" {
  default = 2
  description = "Maximum amount of nodes in autoscaling group"
}
variable "security_groups" {
  type    = "string"
  default = "default"
  description = "Lists the Amazon EC2 security groups to assign to the EC2 instances in the Auto Scaling group in order to define firewall rules for the instances."
}

variable "service_role" {
  default = "terraform-elasticbeanstalk-service-role"
}

variable "ec2_role" {
  default = "terraform-elasticbeanstalk-ec2-role"
}
