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


    egress = [
    {
        cidr_blocks      = [
            "0.0.0.0/0",
        ]
        description      = "All traffic out IPv4"
        from_port        = 0
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    {
        cidr_blocks      = []
        description      = "All traffic out IPv6"
        from_port        = 0
        ipv6_cidr_blocks = [
            "::/0",
        ]
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    ]

    ingress = [
    {
        cidr_blocks      = [
            "0.0.0.0/0",
        ]
        description      = "All traffic in IPv4"
        from_port        = 0
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    {
        cidr_blocks      = [
            "0.0.0.0/0",
        ]
        description      = "ssh in"
        from_port        = 22
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "tcp"
        security_groups  = []
        self             = false
        to_port          = 22
    },
    ]

    tags = {
        Name        = "Identity Plus Security Group"
        Project     = "Identity-Plus-POC"
        Environment = "dev"
    }
    }

# Define a security group that allows incoming traffic on port 443 from anywhere (`0.0.0.0/0`).
resource "aws_security_group" "mTLS_sg" {
    name        = "Identity Plus mTLS sg"
    description = "Security group for example VPC"
    vpc_id     = aws_vpc.identity-plus-vpc.id

    egress = [
    {
        cidr_blocks      = [
            "0.0.0.0/0",
        ]
        description      = "All traffic out IPv4"
        from_port        = 0
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    {
        cidr_blocks      = []
        description      = "All traffic out IPv6"
        from_port        = 0
        ipv6_cidr_blocks = [
            "::/0",
        ]
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    ]

    ingress = [
    {
        cidr_blocks      = [
            "0.0.0.0/0",
        ]
        description      = "All traffic in IPv4"
        from_port        = 0
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    },
    ]

  tags = {
    Name        = "Identity Plus mTLS Security Group"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

# Create a route table for the VPC with an internet exit (egress) to connect to Identity Plus.
resource "aws_route_table" "identity_plus_rt" {
  vpc_id = aws_vpc.identity-plus-vpc.id
  

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.identity_plus_igw.id
  }

  tags = {
    Name        = "Identity Plus route table"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

# resource "aws_main_route_table_association" "identity_plus_association" {
#   depends_on = [ aws_vpc.identity-plus-vpc,aws_route_table.identity_plus_rt ]
#   vpc_id         = aws_vpc.identity-plus-vpc.id
#   route_table_id = aws_route_table.identity_plus_rt.id
# }

resource "aws_internet_gateway" "identity_plus_igw" {
  vpc_id = aws_vpc.identity-plus-vpc.id

  tags = {
    Name        = "Identity Plus IGW"
    Project     = "Identity-Plus-POC"
    Environment = "dev"
  }
}

                # │ Error: creating EC2 Internet Gateway Attachment: attaching EC2 Internet Gateway (igw-0fa5169e08f5461db) to VPC (vpc-0abf426453b84fc69): Resource.AlreadyAssociated: resource igw-0fa5169e08f5461db is already attached to network vpc-0abf426453b84fc69
                # resource "aws_internet_gateway_attachment" "identity_plus_igw_attachment" {
                #   internet_gateway_id = aws_internet_gateway.identity_plus_igw.id
                #   vpc_id              = aws_vpc.identity-plus-vpc.id
                # }

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
  
  associate_public_ip_address = true

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