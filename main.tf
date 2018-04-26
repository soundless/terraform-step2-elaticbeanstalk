provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "default" {
  bucket = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    ignore_changes = ["lifecycle_rule"]
  }
}

resource "aws_s3_bucket_object" "default" {
  # Download the zip file from AWS tutorial (Java SE)
  # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/tutorials.html
  bucket = "${aws_s3_bucket.default.id}"
  key = "beanstalk/java-se-jetty-gradle-v3.zip"
  source = "java-se-jetty-gradle-v3.zip"
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.name_prefix}-instance-profile"
  role = "${aws_iam_role.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "beanstalk_service" {
  name = "${var.service_role}"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Principal": {
      "Service": "elasticbeanstalk.amazonaws.com"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
    "StringEquals": {
      "sts:ExternalId": "elasticbeanstalk"
    }
    }
  }
  ]
}
EOF
}

resource "aws_iam_role" "main" {
  name = "${var.ec2_role}"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
  {
    "Sid": "",
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF
}

resource "null_resource" "setup_roles"{
  depends_on = [
  "aws_iam_role.main",
  "aws_iam_role_policy_attachment.beanstalk_service",
  "aws_iam_role_policy_attachment.beanstalk_service_health",
  "aws_iam_role.beanstalk_service",
  "aws_iam_role_policy_attachment.container_tier",
  "aws_iam_role_policy_attachment.web_tier",
  "aws_iam_role_policy_attachment.worker_tier"
  ]
}

resource "aws_iam_role_policy_attachment" "beanstalk_service" {
  role = "${aws_iam_role.beanstalk_service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_role_policy_attachment" "beanstalk_service_health" {
  role = "${aws_iam_role.beanstalk_service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "worker_tier" {
  role       = "${aws_iam_role.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "web_tier" {
  role       = "${aws_iam_role.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "container_tier" {
  role       = "${aws_iam_role.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_elastic_beanstalk_application" "glxmanager" {
  name = "glxmanager"
  description = "glxmanager - ${var.name_prefix}"
}

# application version
resource "aws_elastic_beanstalk_application_version" "default" {
  application = "glxmanager"
  name = "java-se-jetty-gradle-v3"
  bucket = "${aws_s3_bucket.default.id}"
  key = "${aws_s3_bucket_object.default.id}"
}

resource "aws_elastic_beanstalk_environment" "glxmanager" {
  name = "glxmanager-terraform"
  application = "${aws_elastic_beanstalk_application.glxmanager.name}"
  solution_stack_name = "64bit Amazon Linux 2017.09 v2.6.8 running Java 8"
  version_label = "${aws_elastic_beanstalk_application_version.default.name}"
  wait_for_ready_timeout = "20m"

  depends_on =  ["null_resource.setup_roles"]
  
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name  = "InstanceType"
    value   = "${var.instance_type}"
  } 

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name  = "EC2KeyName"
    value   = "${var.ssh_key}"
  }

  #setting {
  #  namespace = "aws:autoscaling:launchconfiguration"
  #  name    = "SecurityGroups"
  #  value   = "${var.security_groups}"
  #}

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name  = "IamInstanceProfile"
    value   = "${aws_iam_instance_profile.main.arn}"
  }  

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name  = "SSHSourceRestriction"
    value   = "tcp, 22, 22, 0.0.0.0/0"
  } 
  
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name  = "ServiceRole"
    value   = "${var.service_role}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name  = "VPCId"
    value   = "${var.vpc_id}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:xray"
    name  = "XRayEnabled"
    value   = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name = "SystemType"
    value = "enhanced"
  }
  
  setting {
    namespace = "aws:ec2:vpc"
    name  = "Subnets"
    value   = "${var.private_subnet_one},${var.private_subnet_two}"
  }
  
  setting {
    namespace = "aws:ec2:vpc"
    name  = "ELBSubnets"
    value   = "${var.subnet_one},${var.subnet_two}"
  } 
  
  setting {
    namespace = "aws:autoscaling:asg"
    name  = "MaxSize"
    value   = "${var.loadbalancing_max_nodes}"
  } 
  
  setting {
    namespace = "aws:autoscaling:asg"
    name  = "MinSize"
    value   = "${var.loadbalancing_min_nodes}"
  } 
  
  setting {
    # Allows 600 seconds between each autoscaling action
    namespace = "aws:autoscaling:asg"
    name  = "Cooldown"
    value   = "600"
  } 
  
  setting {
    namespace = "aws:elasticbeanstalk:application"
    name  = "Application Healthcheck URL"
    value   = "${var.healthcheck_location}"
  }
  
  setting {
    # High threshold for taking down servers for debugging purposes
    namespace = "aws:elb:healthcheck"
    name  = "Interval"
    value   = "300"
  }
  
  setting {
    # High threshold for taking down servers for debugging purposes
    namespace = "aws:elb:healthcheck"
    name  = "UnhealthyThreshold"
    value   = "10"
  }
  
  setting {
    namespace = "aws:elb:loadbalancer"
    name  = "CrossZone"
    value   = "true"
  }
  
  #setting {
  #  namespace = "aws:elb:listener:443"
  #  name  = "ListenerProtocol"
  #  value   = "HTTPS"
  #}
  
  #setting {
  #  namespace = "aws:elb:listener:443"
  #  name  = "InstancePort"
  #  value   = "80"
  #}
  
  setting {
    namespace = "aws:elb:policies"
    name  = "ConnectionDrainingEnabled"
    value   = "true"
  }
  
  setting {
    namespace = "aws:elb:policies"
    name  = "ConnectionDrainingTimeout"
    value   = "20"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name    = "EnvironmentType"
    value   = "LoadBalanced"
  }
}
