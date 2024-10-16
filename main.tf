terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "terraform-demo" {
  ami             = "ami-02b49a24cfb95941c"
  instance_type   = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  tags = {
    Name = "Self-Healing-EC2"
  }

  # User data script to install and start a web server
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "<html><body><h1>Welcome to the Self-Healing Infrastructure!</h1></body></html>" > /var/www/html/index.html
              EOF
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
  name                   = "aws-lb"
  internal               = false
  load_balancer_type     = "application"
  security_groups        = [aws_security_group.web_sg.id]
  subnets                = ["subnet-0fd03fe111484e590", "subnet-00234091c9aa672f8"]
  enable_deletion_protection = false  
}

# Target group for the Load balancer
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0f14bc78ff630bd2d"

  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Listener for the Load balancer
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.aws_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Auto scaling Launch Configuration
resource "aws_launch_configuration" "app" {
  name            = "app-launch-config-v1"
  image_id        = "ami-02b49a24cfb95941c"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_sg.id]

  lifecycle {
    create_before_destroy = true
  }

  # User data script to install and start a web server
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo '<html><body><h1>Welcome to my website!</h1></body></html>' | sudo tee /var/www/html/index.html
              sudo systemctl restart httpd
              EOF
}


# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_configuration = aws_launch_configuration.app.id
  vpc_zone_identifier  = ["subnet-0fd03fe111484e590", "subnet-00234091c9aa672f8"]
  target_group_arns    = [aws_lb_target_group.app_tg.arn]
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  health_check_type    = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "App-Server"
    propagate_at_launch = true
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm triggers if the CPU utilization is 80% or higher for 10 minutes."
  dimensions = {
    InstanceId = aws_instance.terraform-demo.id
  }
}

# Lambda function with CloudWatch
resource "aws_lambda_function" "self_healing_lambda" {
  function_name    = "self-healing-lambda"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}