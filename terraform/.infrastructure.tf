resource "aws_vpc" "main" {
  cidr_block       = var.VpcCIDR
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[0]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[1]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr[0]
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr[1]
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = var.EnvironmentName
  }
}
resource "aws_eip" "nat_gateway_1_eip" {
  vpc      = true
}
resource "aws_eip" "nat_gateway_2_eip" {
  vpc      = true
}
resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_gateway_1_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "${var.EnvironmentName} NatGateway 1"
  }
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_gateway_2_eip.id
  subnet_id     = aws_subnet.public_subnet_2.id
  tags = {
    Name = "${var.EnvironmentName} NatGateway 2"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.EnvironmentName} Public Route"
  }
}
resource "aws_route_table_association" "public_subnet_rtb_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_subnet_rtb_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw_1.id
  }
  tags = {
    Name = "${var.EnvironmentName} Private Route"
  }
}

resource "aws_route_table_association" "private_subnet_rtb_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw_2.id
  }
  tags = {
    Name = "${var.EnvironmentName} Private Route"
  }
}

resource "aws_route_table_association" "private_subnet_rtb_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_2.id
}

resource "aws_security_group" "noingress_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.EnvironmentName} - No Ingress SG"
  }
}

resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  egress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 202
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id,
  ]
  tags = {
    Name = "${var.EnvironmentName} - ACL"
  }
}

//LoadBalancer For ECS Services
resource "aws_security_group" "lb_sg" {
  name        = "allow_http/s"
  description = "Allow TLS and non TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    from_port   = 8080
    to_port     = 8080
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

  tags = {
    Name = "${var.EnvironmentName} - LoadBalancer SG"
  }
}
