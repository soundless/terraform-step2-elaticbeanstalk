provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_instance_profile" "beanstalk_service" {
  name = "aws-elasticbeanstalk-service-role"
  role = "${aws_iam_role.beanstalk_service.name}"
}

resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name = "aws-elasticbeanstalk-ec2-role"
  role = "${aws_iam_role.beanstalk_ec2.name}"
}

resource "aws_iam_role" "beanstalk_service" {
  name = "aws-elasticbeanstalk-service-role"
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

resource "aws_iam_role" "beanstalk_ec2" {
  name = "aws-elasticbeanstalk-ec2-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
  {
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
  "aws_iam_role.beanstalk_service",
  "aws_iam_instance_profile.beanstalk_service",
  "aws_iam_policy_attachment.beanstalk_service",
  "aws_iam_policy_attachment.beanstalk_service_health",
  "aws_iam_role.beanstalk_ec2",
  "aws_iam_instance_profile.beanstalk_ec2",
  "aws_iam_policy_attachment.beanstalk_ec2_container",
  "aws_iam_policy_attachment.beanstalk_ec2_web",
  "aws_iam_policy_attachment.beanstalk_ec2_worker"
  ]
}

resource "aws_iam_policy_attachment" "beanstalk_service" {
  name = "elastic-beanstalk-service"
  roles = ["${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_policy_attachment" "beanstalk_service_health" {
  name = "elastic-beanstalk-service-health"
  roles = ["${aws_iam_role.beanstalk_service.id}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_worker" {
  name = "elastic-beanstalk-ec2-worker"
  roles = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_web" {
  name = "elastic-beanstalk-ec2-web"
  roles = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_container" {
  name = "elastic-beanstalk-ec2-container"
  roles = ["${aws_iam_role.beanstalk_ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}


resource "aws_elastic_beanstalk_application" "glxmanager" {
  name = "test-glxmanager"
  description = "REST glxmanager"
}

resource "aws_elastic_beanstalk_environment" "glxmanager" {
  name = "glxmanager"
  application = "${aws_elastic_beanstalk_application.glxmanager.name}"
  solution_stack_name = "64bit Amazon Linux 2017.09 v2.6.8 running Java 8"
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
    value   = "${aws_iam_instance_profile.beanstalk_ec2.name}"
  }  

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name  = "ServiceRole"
    value   = "${aws_iam_instance_profile.beanstalk_service.name}"
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
    namespace = "aws:autoscaling:launchconfiguration"
    name  = "SSHSourceRestriction"
    value   = "tcp, 22, 22, ${var.vpc_cidr}"
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

output "glxmanager_cname" {
  value = "${aws_elastic_beanstalk_environment.glxmanager.cname}" 
}
