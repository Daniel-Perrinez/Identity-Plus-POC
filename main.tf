provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "identity-plus-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "Identity Plus VPC"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

# Create a subnet within the VPC for your VMs
resource "aws_subnet" "identity-plus-lan-subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.identity-plus-vpc.id
  availability_zone = "us-east-1a"

  tags = {
    Name        = "Identity Plus LAN Subnet"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

# Create a security group to restrict incoming traffic to SSH and HTTP
resource "aws_security_group" "identity_plus_sg" {
  name        = "identity-plus-sg"
  description = "Security group for Identity Plus VPC"
  vpc_id     = aws_vpc.identity-plus-vpc.id

  #allow incoming traffic on SSH (port 22) and HTTP (port 80), from anywhere (`0.0.0.0/0`).
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
}

# Define a security group that allows incoming traffic on port 443 from anywhere (`0.0.0.0/0`).
resource "aws_security_group" "mTLS_sg" {
  name        = "example-sg"
  description = "Security group for example VPC"
  vpc_id     = aws_vpc.identity-plus-vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a route table for the VPC with an internet exit (egress) to connect to Identity Plus.
resource "aws_route_table" "identity_plus_rt" {
  vpc_id = aws_vpc.identity-plus-vpc.id
  

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.identity_plus_igw.id
  }
}

resource "aws_main_route_table_association" "identity_plus_association" {
  vpc_id         = aws_vpc.identity-plus-vpc.id
  route_table_id = aws_route_table.identity_plus_rt.id
}

resource "aws_internet_gateway" "identity_plus_igw" {
  vpc_id = aws_vpc.identity-plus-vpc.id

  tags = {
    Name        = "Identity Plus IGW"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

resource "aws_internet_gateway_attachment" "identity_plus_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.identity_plus_igw.id
  vpc_id              = aws_vpc.identity-plus-vpc.id
}

# ----------------------------------------------------------------------------------------------------------------

# Define the Ubuntu 24.04 LTS (x86_64) AMI
data "aws_ami" "ubuntu_2404_x86_64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create an RSA PEM key pair localy with 'ssh-keygen -t rsa'
# resource "aws_key_pair" "identity_plus-key" {
#   key_name   = "identity_plus-key"
#   key_type   = RSA
#   #pw = abc123
# }

# Create three VMs running Ubuntu 24.04 LTS (x86_64), each with 1 GB of RAM and 30 GB of disk space
resource "aws_instance" "identity-plus-mTLS_Gateway_VM" {
  ami           = data.aws_ami.ubuntu_2404_x86_64.id
  instance_type = "t2.micro" #1Gb memory
  vpc_security_group_ids = [aws_security_group.mTLS_sg.id, aws_security_group.identity_plus_sg.id]
  subnet_id     = aws_subnet.identity-plus-lan-subnet.id

  associate_public_ip_address = true
  key_name = "identity_plus-key"

  root_block_device {
    volume_size           = 30 # in GiB
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name        = "Identity Plus mTLS gateway VM"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

resource "aws_instance" "identity-plus-vms" {
  count = 2

  ami           = data.aws_ami.ubuntu_2404_x86_64.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.identity_plus_sg.id]
  subnet_id     = aws_subnet.identity-plus-lan-subnet.id
  
  root_block_device {
    volume_size           = 30 # in GiB
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name        = "Identity Plus VM ${count.index}"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

# ----------------------------------------------------------------------------------------------------------------
output "ubuntu_2404_x86_64_ami_id" {
  value       = data.aws_ami.ubuntu_2404_x86_64.id
  description = "The ID of the latest Ubuntu 22.04 LTS x86_64 AMI"
}