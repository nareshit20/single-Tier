variable "admin_password" {
  description = "password for windows instance"
  default     = "OyqtS6erMz82IS5XL&umc9Gria)VSiuO"
}
variable "type" {
  type = string
}

resource "aws_vpc" "vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.environment}-vpc"
    Environment = local.environment
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraformigw1"
  }
}
resource "aws_route_table" "table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "NewRoute1"
  }
}
resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.table.id
}
resource "aws_subnet" "public" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    "Name" = "Public subnet - ${element(local.availability_zones, count.index)}"
  }
}


resource "aws_security_group" "Instance_SG" {
  name        = "Instance-SG1"
  description = "Traffic to EC2"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "instances aws security group"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    #cidr_blocks = [aws_vpc.main.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "instances aws security group"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
      ingress {
    description = "instances aws security group"
    from_port   = 3389
    to_port     = 3389
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "windows-SG"
  }
}
resource "aws_instance" "awsvm" {
  count                  = 1
  ami                    = local.ami
  key_name               = local.key_name
  instance_type          = local.type
  vpc_security_group_ids = [aws_security_group.Instance_SG.id]
  subnet_id              = aws_subnet.public[count.index].id
  connection{
  type = "winrm"
  port = 5986
  //host = "ec2-54-213-60-118.us-west-2.compute.amazonaws.com"
  user = "Administrator"
  password = "${var.admin_password}"
  https = true
  timeout  = "2m"
  insecure = true
  }
  tags = merge(
    {
      "Name" = length(aws_subnet.public[0].id) > 1 || local.use_num_suffix ? format("%s${local.num_suffix_format}", "WindEnv", count.index + 1) : "WindEnv"
    }
  )
}

locals {
  environment                = "wind"
  availability_zones         = ["us-east-2a", "us-east-2b", "us-east-2c"]
  region                     = "us-east-2"
  vpc_cidr                   = "10.0.0.0/16"
  instance_count             = 1
  ami                        = "ami-08997ac119e576ab9"
  key_name                   = "voiceanalyticskeypair"
  use_num_suffix             = false
  num_suffix_format          = "-%d"
  type                       = var.type != "" ? var.type : "t2.micro"
  idle_timeout               = 60
  enable_deletion_protection = false
}
