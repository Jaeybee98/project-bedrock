# =======================================================
# 1. THE DEVELOPER IDENTITY (bedrock-dev-view)
# =======================================================

resource "random_password" "dev_console_password" {
  length  = 16
  special = true
}

resource "aws_iam_user" "dev_user" {
  name          = "bedrock-dev-view"
  force_destroy = true
  tags          = { Project = "karatu-2025-capstone" }
}

resource "aws_iam_user_login_profile" "dev_login" {
  user                    = aws_iam_user.dev_user.name
  password_length         = 16
  password_reset_required = false
}

# Generate programmatic execution access tokens for grading validations
resource "aws_iam_access_key" "dev_keys" {
  user = aws_iam_user.dev_user.name
}

# Attach Standard Console Read-Only View Permissions
resource "aws_iam_user_policy_attachment" "console_read_only" {
  user       = aws_iam_user.dev_user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Attach the specific permission required to upload objects to the asset bucket
resource "aws_iam_user_policy" "dev_s3_upload_policy" {
  name = "bedrock-dev-s3-upload-access"
  user = aws_iam_user.dev_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:PutObjectAcl"]
      Resource = "${module.storage.assets_bucket_arn}/*"
    }]
  })
}


# =======================================================
# 2. MODERN NATIVE EKS CLUSTER RBAC MAPPING
# =======================================================

# Map the IAM User directly into the cluster API plane using Access Entries
resource "aws_eks_access_entry" "dev_cluster_entry" {
  cluster_name      = module.compute.cluster_name
  principal_arn     = aws_iam_user.dev_user.arn
  user_name         = "bedrock-dev-view"
  type              = "STANDARD"
}

# Bind the native read-only view ClusterRole to this specific user namespace scope
resource "aws_eks_access_policy_association" "dev_view_policy" {
  cluster_name  = module.compute.cluster_name
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_user.dev_user.arn
  
  access_scope {
    type       = "namespace"
    namespaces = ["retail-app", "kube-system"]
  }
}


# =======================================================
# 3. SERVERLESS ASSET ENGINE (Lambda & S3 Triggers)
# =======================================================

# Dynamically compress the source function payload on execution runtimes
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/asset_processor.py"
  output_path = "${path.module}/../lambda/asset_processor.zip"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "project-bedrock-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Project = "karatu-2025-capstone" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_lambda_function" "asset_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "bedrock-asset-processor"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "asset_processor.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 15

  tags = { Name = "bedrock-asset-processor", Project = "karatu-2025-capstone" }
}

# Allow Amazon S3 to break boundary logic to execute the function trigger hooks
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.storage.assets_bucket_arn
}

# Set up the event notification trigger on the marketing assets bucket
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.storage.assets_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invocation]
}


# =======================================================
# EXTRA SECURE DELIVERABLES GENERATION OUTPUTS
# =======================================================

output "dev_iam_user_console_login" {
  value       = "https://signin.aws.amazon.com/console"
  description = "AWS Management Console access link."
}

output "dev_iam_user_username" {
  value       = aws_iam_user.dev_user.name
}

output "dev_iam_user_password" {
  value     = aws_iam_user_login_profile.dev_login.password
  sensitive = true
}

output "dev_iam_user_access_key_id" {
  value       = aws_iam_access_key.dev_keys.id
  description = "Required evaluation credential key identifier."
}

output "dev_iam_user_secret_access_key" {
  value     = aws_iam_access_key.dev_keys.secret
  sensitive = true
}

# Grant the AWS Root User access to the EKS cluster access engine
resource "aws_eks_access_entry" "root_cluster_entry" {
  cluster_name  = module.compute.cluster_name
  principal_arn = "arn:aws:iam::958850199225:root"
  type          = "STANDARD"
}

# Associate the native ClusterAdmin policy to the Root User entry
resource "aws_eks_access_policy_association" "root_admin_policy" {
  cluster_name  = module.compute.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::958850199225:root"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.root_cluster_entry]
}
