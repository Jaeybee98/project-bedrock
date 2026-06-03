# --- SECURITY GROUPS FOR RDS ---

# MySQL Security Group
resource "aws_security_group" "mysql_sg" {
  name        = "project-bedrock-mysql-sg"
  description = "Allow inbound MySQL traffic from EKS worker nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS Nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_cluster_sg_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "project-bedrock-mysql-sg", Project = "karatu-2025-capstone" }
}

# PostgreSQL Security Group
resource "aws_security_group" "postgres_sg" {
  name        = "project-bedrock-postgres-sg"
  description = "Allow inbound PostgreSQL traffic from EKS worker nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS Nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_sg_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "project-bedrock-postgres-sg", Project = "karatu-2025-capstone" }
}

# --- AWS SECRETS MANAGER FOR DB CREDENTIALS ---

resource "random_password" "db_password" {
  length  = 16
  special = false # Keeps characters safe for DB connection string formats
}

resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "project-bedrock-db-credentials"
  recovery_window_in_days = 0 # Ensures fast cleanups if redeploying
  tags                    = { Project = "karatu-2025-capstone" }
}

resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    mysql_user     = "catalog_admin"
    mysql_password = random_password.db_password.result
    mysql_db       = "catalog"
    pgsql_user     = "orders_admin"
    pgsql_password = random_password.db_password.result
    pgsql_db       = "orders"
  })
}

# --- MANAGED DATABASE INSTANCES ---

# MySQL Database Engine (For Catalog Service)
resource "aws_db_instance" "mysql" {
  identifier             = "project-bedrock-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro" # Keeps instance footprint low and cost-optimized
  allocated_storage      = 20
  max_allocated_storage  = 50
  db_name                = "catalog"
  username               = "catalog_admin"
  password               = random_password.db_password.result
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  skip_final_snapshot    = true

  tags = { Name = "project-bedrock-mysql", Project = "karatu-2025-capstone" }
}

# PostgreSQL Database Engine (For Orders Service)
resource "aws_db_instance" "postgres" {
  identifier             = "project-bedrock-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 50
  db_name                = "orders"
  username               = "orders_admin"
  password               = random_password.db_password.result
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  skip_final_snapshot    = true

  tags = { Name = "project-bedrock-postgres", Project = "karatu-2025-capstone" }
}

# --- AMAZON DYNAMODB (For Carts/Dynamic State) ---

resource "aws_dynamodb_table" "carts_table" {
  name           = "project-bedrock-carts"
  billing_mode   = "PAY_PER_REQUEST" # Serverless pricing optimization
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Name = "project-bedrock-carts", Project = "karatu-2025-capstone" }
}

# --- IMMUTABLE S3 MARKETING ASSET BUCKET (Requirement 4.5) ---

resource "aws_s3_bucket" "assets" {
  bucket        = "bedrock-assets-${var.student_id}"
  force_destroy = true # Facilitates easy teardown post-grading

  tags = { Name = "bedrock-assets-${var.student_id}", Project = "karatu-2025-capstone" }
}

resource "aws_s3_bucket_public_access_block" "assets_privacy" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- MODULE VARIABLES ---
variable "vpc_id" { type = string }
variable "eks_cluster_sg_id" { type = string }
variable "db_subnet_group_name" { type = string }
variable "student_id" { type = string }

# --- MODULE OUTPUTS ---
output "mysql_endpoint" { value = aws_db_instance.mysql.endpoint }
output "postgres_endpoint" { value = aws_db_instance.postgres.endpoint }
output "dynamodb_table_name" { value = aws_dynamodb_table.carts_table.name }
output "assets_bucket_arn" { value = aws_s3_bucket.assets.arn }
output "assets_bucket_id" { value = aws_s3_bucket.assets.id }
