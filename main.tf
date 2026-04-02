resource "aws_vpc" "main" { 
  cidr_block = "10.0.0.0/22"
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true 
} 

resource "aws_subnet" "private" { 
  count = 2 
  vpc_id = aws_vpc.main.id 
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2) 
}

resource "aws_security_group" "alb_sg" { 
  vpc_id = aws_vpc.main.id 
  
  ingress { 
    from_port = 80 
    to_port = 80 
    protocol = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  } 
}

resource "aws_lb" "app_alb" { 
  name = "app-alb" 
  internal = false 
  load_balancer_type = "application" 
  subnets = aws_subnet.public[*].id 
}

resource "aws_launch_template" "app_lt" { 
  name_prefix = "app-lt" 
  image_id = "ami-0c55b159cbfafe1f0" 
  instance_type = "t3.micro" 

user_data = base64encode(<<-EOF
  #!/bin/bash
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "Hello from Terraform ASG" > /var/www/html/index.html
EOF
)
}

resource "aws_autoscaling_group" "app_asg" { 
  desired_capacity = 2 
  max_size = 3 
  min_size = 1 
  vpc_zone_identifier = aws_subnet.public[*].id 
  
  launch_template { 
    id = aws_launch_template.app_lt.id 
    version = "$Latest" 
  } 
}

resource "aws_db_instance" "db" { 
  allocated_storage = 20 
  engine = "mysql" 
  instance_class = "db.t3.micro" 
  username = "admin" 
  password = "Password123!" 
  skip_final_snapshot = true 
}
