terraform {
  backend "s3" {
    bucket = "mdv-devops-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

#===============================================================================

#==============================Create VPC=======================================

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-VPC" })
}

#============================Create Subnets=====================================

resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "${var.name}-public-subnet-A" })
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "192.168.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = merge(var.tags, { Name = "${var.name}-public-subnet-B" })
}

#========================Create Internet Gateway================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.tags, { Name = "${var.name}-Internet Gateway" })
}

#============================Create Route Tables================================

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, { Name = "${var.name}-Route Table" })
}

#==============================Assosiate Routes=================================

resource "aws_route_table_association" "internet_access_public_subnet_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "internet_access_public_subnet_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.rt.id
}

#============================Create Security Group==============================

resource "aws_security_group" "sg" {
  name        = "${var.creator}-SecurityGroup"
  description = "Allow TLS & SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-Security Group" })
}

#=========================Create Launch Configuration===========================

resource "aws_launch_configuration" "lc" {
  name_prefix                 = "LC-"
  image_id                    = data.aws_ami.latest_amazon_linux_ami.id
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.sg.id]
  associate_public_ip_address = true
  user_data                   = file("data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#=========================Create Autoscaling Group==============================

resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.name}-ASG-${aws_launch_configuration.lc.name}"
  launch_configuration      = aws_launch_configuration.lc.name
  min_size                  = 2
  max_size                  = 2
  health_check_type         = "ELB"
  min_elb_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  load_balancers            = [aws_elb.lb.name]
  wait_for_capacity_timeout = "0"

  dynamic "tag" {
    for_each = {
      Name  = "${var.name} server created by ASG"
      Owner = var.creator
      Stage = var.name
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

#============================Create Load Balancer===============================

resource "aws_elb" "lb" {
  name            = "${var.name}-elb"
  security_groups = [aws_security_group.sg.id]
  subnets         = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.cert.id
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
  tags = merge(var.tags, { Name = "${var.name}-Load Balancer" })
}

#========================Create Route53 Record==================================

resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.lb.dns_name
    zone_id                = aws_elb.lb.zone_id
    evaluate_target_health = true
  }
}
