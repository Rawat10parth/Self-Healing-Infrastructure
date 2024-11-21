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

# Create an IAM Role for EC2 instance
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "EC2CloudWatchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the necessary policy to allow CloudWatch actions
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "CloudWatchLogsPolicy"
  description = "Policy to allow EC2 to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "cloudwatch:PutMetricData",
          "ec2:DescribeTags",
          "autoscaling:DescribeAutoScalingGroups",
          "ssm:GetParameter",
          "ssm:PutParameter",
          "ssm:DescribeParameters",
          "ssm:ListAssociations",
          "ssm:UpdateInstanceInformation"
        ],
        Resource = "*"
      }
    ]
  })
}

# Add SSM policy attachments to the EC2 role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_cloudwatch_instance_profile" {
  name = "CloudWatchAgentInstanceProfile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

# Attach the CloudWatch policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_attachment" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach CloudWatchFullAccess policy to the EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}


resource "aws_instance" "terraform-demo" {
  ami             = "ami-02b49a24cfb95941c"
  instance_type   = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  iam_instance_profile = aws_iam_instance_profile.ec2_cloudwatch_instance_profile.name
  
  tags = {
    Name = "Self-Healing-EC2"
  }

  # User data script to install and start a web server
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              apt-get install -y amazon-cloudwatch-agent
              apt-get install -y awslogs
              systemctl start apache2
              systemctl enable apache2
              systemctl start awslogsd
              systemctl enable awslogsd.service
              echo "<html><body><h1>Welcome to the Self-Healing Infrastructure!</h1></body></html>" > /var/www/html/index.html
              
              mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
              
              # Create CloudWatch Agent configuration
              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root",
                  "debug": true
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/apache2/access.log",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-access",
                          "timestamp_format": "%d/%b/%Y:%H:%M:%S %z"
                        },
                        {
                          "file_path": "/var/log/apache2/error.log",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-error",
                          "timestamp_format": "%b %d %H:%M:%S.%L %Y"
                        },
                        {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-syslog",
                          "timestamp_format": "%b %d %H:%M:%S"
                        }
                      ]
                    }
                  }
                },
                "metrics": {
                  "metrics_collected": {
                    "mem": {
                      "measurement": ["mem_used_percent"]
                    },
                    "swap": {
                      "measurement": ["swap_used_percent"]
                    }
                  }
                }
              }
              EOT

              # Set proper permissions
              chmod 644 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

              # Start CloudWatch Agent with custom configuration
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config -m ec2 \
              -c ssm:/AmazonCloudWatch-agent-config \
              -s
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start

              # Ensure Apache2 logs are readable by CloudWatch agent
              chmod 644 /var/log/apache2/access.log
              chmod 644 /var/log/apache2/error.log
              
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

  # Add IAM instance profile to the launch configuration
  iam_instance_profile = aws_iam_instance_profile.ec2_cloudwatch_instance_profile.name

  # User data script to install and start a web server
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo yum install -y amazon-cloudwatch-agent
              sudo yum install -y awslogs
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo systemctl start awslogsd
              sudo systemctl enable awslogsd.service
              echo '<html><body><h1>Welcome to my website!</h1></body></html>' | sudo tee /var/www/html/index.html
              
              # Create CloudWatch Agent configuration directory
              mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
              
              # Create CloudWatch Agent configuration
              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "agent": {
                  "metrics_collection_interval": 10,
                  "run_as_user": "root"
                  "debug":true
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/httpd/access_log",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-access",
                          "timestamp_format": "%d/%b/%Y:%H:%M:%S %z"
                        },
                        {
                          "file_path": "/var/log/httpd/error_log",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-error",
                          "timestamp_format": "%b %d %H:%M:%S.%L %Y"
                        },
                        {
                          "file_path": "/var/log/messages",
                          "log_group_name": "/ec2/instance-logs",
                          "log_stream_name": "{instance_id}-system",
                          "timestamp_format": "%b %d %H:%M:%S"
                        }
                      ]
                    }
                  }
                },
                "metrics": {
                  "metrics_collected": {
                    "mem": {
                      "measurement": ["mem_used_percent"]
                    },
                    "swap": {
                      "measurement": ["swap_used_percent"]
                    },
                    "cpu": {
                      "measurement": [
                        "cpu_usage_idle",
                        "cpu_usage_user",
                        "cpu_usage_system"
                      ],
                      "metrics_collection_interval": 10
                    }
                  },
                  "append_dimensions": {
                    "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
                    "InstanceId": "$${aws:InstanceId}",
                    "InstanceType": "$${aws:InstanceType}"
                  }
                }
              }
              EOT

                # Set proper permissions
              chmod 644 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

              # Start CloudWatch Agent with custom configuration
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start

              # Ensure Apache logs are readable by CloudWatch agent
              chmod 644 /var/log/httpd/*log
              
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

# Define the CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name              = "/ec2/instance-logs"
  retention_in_days = 30
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This alarm triggers if the CPU utilization is 50% or higher for 10 minutes."
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