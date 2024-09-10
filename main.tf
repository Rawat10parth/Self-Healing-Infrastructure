terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "terraform-demo" {
  ami = "ami-02b49a24cfb95941c"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "Self-Healing-EC2"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Load balancer
resource "aws_lb" "aws_lb" {
  name = "aws-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.web_sg.id]
  subnets = [/*subnet-0fd03fe111484e590*/]
  enable_deletion_protection = false  
}

# Target group for the Load balancer
resource "aws_lb_target_group" "app_tg" {
  name = "app-tg"
  port = 80
  protocol = "HTTP"
  vpc_id =   "vpc-0f14bc78ff630bd2d"

  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 5
    unhealthy_threshold = 2
    matcher = "200"
  }
}

# Listener for the Load balancer
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.aws_lb.arn
  port              = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Auto scaling Launch Configuration
resource "aws_launch_configuration" "app" {
  name = "app-launch-config"
  image_id = "ami-02b49a24cfb95941c"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web_sg.id]

  lifecycle {
    create_before_destroy = true
  }

  # User data script to install and start a web server
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              EOF
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_configuration = aws_launch_configuration.app.id
  vpc_zone_identifier =  [/*subnet-0fd03fe111484e590*/]
  target_group_arns = [aws_lb_target_group.app_tg.arn]
  min_size = 1
  max_size = 3
  desired_capacity = 2
  health_check_type = "EC2"
  health_check_grace_period = 300

  tag {
    key = "Name"
    value = "App-Server"
    propagate_at_launch = true
  }
}