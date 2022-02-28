resource "aws_vpc" "food-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "food"
  }
}

resource "aws_subnet" "food-subnet-public-a" {
  vpc_id                  = aws_vpc.food-vpc.id
  cidr_block              = "10.0.11.0/24"
  map_public_ip_on_launch = true // public subnet
  availability_zone       = "eu-west-1a"
  tags = {
    Name       = "food-subnet-public-a"
    Visibility = "public"
  }
}

resource "aws_subnet" "food-subnet-public-b" {
  vpc_id                  = aws_vpc.food-vpc.id
  cidr_block              = "10.0.12.0/24"
  map_public_ip_on_launch = true // public subnet
  availability_zone       = "eu-west-1b"
  tags = {
    Name       = "food-subnet-public-b"
    Visibility = "public"
  }
}

resource "aws_subnet" "food-subnet-private-a" {
  vpc_id                  = aws_vpc.food-vpc.id
  cidr_block              = "10.0.21.0/24"
  map_public_ip_on_launch = false // private subnet
  availability_zone       = "eu-west-1a"
  tags = {
    Name       = "food-subnet-private-a"
    Visibility = "private"
  }
}

resource "aws_subnet" "food-subnet-private-b" {
  vpc_id                  = aws_vpc.food-vpc.id
  cidr_block              = "10.0.22.0/24"
  map_public_ip_on_launch = false // private subnet
  availability_zone       = "eu-west-1b"
  tags = {
    Name       = "food-subnet-private-b"
    Visibility = "private"
  }
}

resource "aws_internet_gateway" "food-gateway" {
  vpc_id = aws_vpc.food-vpc.id
  tags = {
    Name = "food-gateway"
  }
}

resource "aws_route_table" "food-public-routetable" {
  vpc_id = aws_vpc.food-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.food-gateway.id
  }
  tags = {
    Name       = "food-public-routetable"
    Visibility = "public"
  }
}

resource "aws_route_table" "food-private-routetable" {
  vpc_id = aws_vpc.food-vpc.id
  tags = {
    Name       = "food-private-routetable"
    Visibility = "private"
  }
}

resource "aws_route_table_association" "food-subnet-public-a" {
  subnet_id      = aws_subnet.food-subnet-public-a.id
  route_table_id = aws_route_table.food-public-routetable.id
}

resource "aws_route_table_association" "food-subnet-public-b" {
  subnet_id      = aws_subnet.food-subnet-public-b.id
  route_table_id = aws_route_table.food-public-routetable.id
}

resource "aws_route_table_association" "food-subnet-private-a" {
  subnet_id      = aws_subnet.food-subnet-private-a.id
  route_table_id = aws_route_table.food-private-routetable.id
}

resource "aws_route_table_association" "food-subnet-private-b" {
  subnet_id      = aws_subnet.food-subnet-private-b.id
  route_table_id = aws_route_table.food-private-routetable.id
}
