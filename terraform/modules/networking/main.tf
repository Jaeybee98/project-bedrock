resource "aws_vpc" "bedrock_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "project-bedrock-vpc"
    Project = "karatu-2025-capstone"
  }
}

# Internet Gateway for Public Traffic
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.bedrock_vpc.id

  tags = {
    Name    = "project-bedrock-igw"
    Project = "karatu-2025-capstone"
  }
}

# --- SUBNETS ---

# Public Subnets (For ALB Ingress & NAT Gateways)
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.bedrock_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "project-bedrock-public-${var.azs[count.index]}"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
    "kubernetes.io/role/elb"                    = "1" # Crucial for Public ALB discovery
    Project                                     = "karatu-2025-capstone"
  }
}

# Private Subnets (For EKS Node Groups)
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.bedrock_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = var.azs[count.index]

  tags = {
    Name                                        = "project-bedrock-private-${var.azs[count.index]}"
    "kubernetes.io/cluster/project-bedrock-cluster" = "shared"
    "kubernetes.io/role/internal-elb"           = "1" # Crucial for Internal Load Balancers
    Project                                     = "karatu-2025-capstone"
  }
}

# Database Subnets (Isolated for RDS)
resource "aws_subnet" "database" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.bedrock_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = var.azs[count.index]

  tags = {
    Name    = "project-bedrock-db-${var.azs[count.index]}"
    Project = "karatu-2025-capstone"
  }
}

# --- NAT GATEWAYS (High Availability: 1 per Public AZ) ---

resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"

  tags = {
    Name    = "project-bedrock-nat-eip-${var.azs[count.index]}"
    Project = "karatu-2025-capstone"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "project-bedrock-nat-${var.azs[count.index]}"
    Project = "karatu-2025-capstone"
  }
}

# --- ROUTE TABLES & ASSOCIATIONS ---

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.bedrock_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "project-bedrock-public-rt"
    Project = "karatu-2025-capstone"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (Pointed to corresponding NAT Gateways)
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.bedrock_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name    = "project-bedrock-private-rt-${var.azs[count.index]}"
    Project = "karatu-2025-capstone"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# RDS Subnet Group Configuration
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "project-bedrock-rds-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name    = "project-bedrock-rds-subnet-group"
    Project = "karatu-2025-capstone"
  }
}

# --- MODULE VARIABLES & OUTPUTS ---

variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }

output "vpc_id" { value = aws_vpc.bedrock_vpc.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "database_subnet_group_name" { value = aws_db_subnet_group.rds_subnet_group.name }
output "private_subnet_cidr_blocks" { value = aws_subnet.private[*].cidr_block }
