# AWS Provider Details
provider "aws" {
  region        = "${var.region}"
  access_key    = "${var.access_key}"
  secret_key    = "${var.secret_key}"
}


# Push Public key to Key pair
resource "aws_key_pair" "ec2-instance" {
  key_name      = "ec2-instance"
  public_key    = "${file(var.public_key)}"
}


# Create EC2 Instance with 
resource "aws_instance" "ec2-instance" {
  connection {
    user        = "${var.aws_default_user}"
    private_key = "${file(var.private_key)}"
}

  ami                                  = "${var.ami-id}"
  instance_type                        = "${var.instance-type}"
  key_name                             = "ec2-instance"
  instance_initiated_shutdown_behavior = "terminate"
  tags {
    Name                               = "ec2-instance"
    Environment                        = "${var.environment_tag}"
       }


  # Execute the commands into newly created EC2 instance

  provisioner "remote-exec" {
    inline = [
      "sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash",    #Install NVM
      "sudo yum -y install nginx",
      "sudo yum -y install git",
      "sudo yum -y install gcc-c++ make",
      "sudo nvm install node"                                                                    #Install Node JS 20
      "sudo curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",    
      "sudo nvm install v20.0.0                 
      "sudo apt-get install --yes nodejs",                                                      
      "sudo apt-get install --yes build-essential"
      "sudo yum -y install python-setuptools",
      "sudo easy_install supervisor",  
      "sudo npm install pm2 -g"                                                                  #Install PM2
      ]
  }
  provisioner "file" {
    source      = "./scripts"
    destination = "/tmp/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "sudo /tmp/scripts/nginx_conf.sh",
      "sudo /tmp/scripts/startnodejs.sh",
      "sudo service nginx start",
    ]
  }
}



# Create AMI from newly created EC2 instance
resource "aws_ami_from_instance" "ec2-instance-ami" {
  name                 = "ec2-instance-ami"
  source_instance_id   = "${aws_instance.ec2-instance.id}"
  tags {
    Environment        = "${var.environment_tag}"
  }
}



# Create Launch Template for ASG
resource "aws_launch_template" "ec2-instance-ami" {
  name_prefix          = "ec2-instance-lt"
  image_id             = "${aws_ami_from_instance.ec2-instance-ami.id}"
  instance_type        = "${var.instance-type}"
  key_name             = "ec2-instance-ami"
  tags {
    Name               = "ec2-instance-UI"
    Environment        = "${var.environment_tag}"
  }
}

# Create Placement group
resource "aws_placement_group" "ec2-instance-placement" {
  name                 = "ec2-instance-placement"
  strategy             = "spread"
}

# Create ASG
resource "aws_autoscaling_group" "ec2-instance-asg" {
  name                      = "ec2-instance-ASG"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 60                                                           
  health_check_type         = "ELB"
  placement_group           = "${aws_placement_group.ec2-instance-placement.id}"
  availability_zones        = ["${aws_instance.ec2-instance.availability_zone}"]
  target_group_arns         = ["${aws_lb_target_group.ec2-instance-targetgroup.arn}"]

  launch_template {
    id          = "${aws_launch_template.ec2-instance-lt.id}"
    version     = "$Default"
  }
}

# Create Loadbalancer target group
resource "aws_lb_target_group" "ec2-instance-targetgroup" {
  name          = "ec2-instance-targetgroup"
  port          = "80"
  protocol      = "HTTP"
  vpc_id        = "${aws_default_vpc.default.id}"
  target_type   = "instance"
  tags {
    name        = "ec2-instance-UItarget"
    ENV         = "${var.environment_tag}"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = "80"
  }
}




#VPC
resource "aws_default_vpc" "vpc"{
    intance_tenancy                = "default"
    enable_dns_hostnames           = true
    enable_dns_support             = false
    enable_classiclink             = false
    enable_classiclink_dns_support = false

lifecycle {
    prevent_destroy = true
    ignore_changes = all
    }
}

#Internet gateway
resource "aws_internet_gateway" "inet-gw" {
    depends on = [aws_default_vpc.vpc]
    vpc_id     = aws_default_vpc.vpc.id

lifecycle {
    prevent_destroy = true
    ignore_changes = all
    }
}


# Get subnet Availability Zone
resource "aws_default_subnet" "defaultsubnet1" {                                        
  availability_zone = "${var.availability_zone}"
  tags  {
    Name        = "Default subnet1"
  }
}



# Get Default Security Group
resource "aws_defult_security_group" "default" {
    vpc_id         = aws_default_vpc.vpc.id
    ingress {
        protocol   = "-1"                                   #tcp
        self       = true
        from_port  = 0                                      #insert port
        to_port    = 0                                      #insert port
        ip_address = ["27.110.146.235"]                     #insert cidr block of that ip or secgroup id 


    }
    egress {
        from_port = 0                                       #insert port
        to_port   = 0                                       #insert port
        protocol  = "-1"                                    #tcp
    }
    
}




# Create ELB - Application loadbalancer
resource "aws_lb" "ec2-instance-elb" {
  name               = "ec2-instance-elb"
  subnets            = ["${aws_default_subnet.defaultsubnet1.id}","${aws_default_subnet.defaultsubnet2.id}"]
  internal           = false
  load_balancer_type = "application"
 # security_groups   = ["${aws_security_group.CF2TF-SG-Web.id}"]

  tags {
    Name        = "UIWeb-FrontEnd"
    ENV         = "${var.environment_tag}"
  }
}

# Create Application LB listener
resource "aws_lb_listener" "ec2-instance-listener" {
  load_balancer_arn = "${aws_lb.ec2-instance-elb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn    = "${aws_lb_target_group.ec2-instance-targetgroup.arn}"
    type                = "forward"
  }
}

# Terminate instance after creating AMI
resource "null_resource" "postexecution" {
  depends_on    = ["aws_ami_from_instance.ec2-instance-ui-ami"]
  connection {

    host        = "${aws_instance.ec2-instance.public_ip}"
    user        = "${var.aws_default_user}"
    private_key = "${file(var.private_key)}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo init 0"
    ]
  }
}

# SNS notification if EC2 cpu usage more than 75%
resource "aws_sns_topic" "ec2-instance-topic" {
  name = "alarms-topic"
  provisioner "local-exec" {
    command = "export AWS_ACCESS_KEY_ID=${var.access_key} ; export AWS_SECRET_ACCESS_KEY=${var.secret_key}; aws sns subscribe --topic-arn ${aws_sns_topic.ec2-instance-topic.arn} --protocol email --notification-endpoint ${var.emails} --region ${var.region}"
  }
}

# Cloudwatch Alarm if EC2 instance CPU usage reached 75 %
resource "aws_cloudwatch_metric_alarm" "ec2-instance-health" {
  alarm_name            = "ASG_Instance_CPU"
  depends_on            = ["aws_sns_topic.ec2-instance-topic", "aws_autoscaling_group.ec2-instance-asg"]
  comparison_operator   = "GreaterThanOrEqualToThreshold"
  evaluation_periods    = "2"
  metric_name           = "CPUUtilization"
  namespace             = "AWS/EC2"
  period                = "120"
  statistic             = "Average"
  threshold             = "75"
  alarm_actions         = ["${aws_sns_topic.ec2-instance-topic.arn}"]
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.ec2-instance-asg.name}"
  }
}
