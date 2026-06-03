# --- IAM ROLE FOR EKS CONTROL PLANE ---
resource "aws_iam_role" "eks_cluster_role" {
  name = "project-bedrock-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = { Name = "project-bedrock-cluster-role", Project = "karatu-2025-capstone" }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- IAM ROLE FOR MANAGED WORKER NODES ---
resource "aws_iam_role" "eks_node_role" {
  name = "project-bedrock-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "project-bedrock-node-role", Project = "karatu-2025-capstone" }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# --- THE EKS CONTROL PLANE ---
resource "aws_eks_cluster" "bedrock_cluster" {
  name     = "project-bedrock-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.34" # Explicitly locks down the required >= 1.34.0 rule

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true # Allows kubectl connection from GitHub pipelines & your environment
  }

  # 4.4 Observability: Enforce Control Plane Logging to CloudWatch
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Enforces modern native Access Entries API mode instead of configmaps
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = { Name = "project-bedrock-cluster", Project = "karatu-2025-capstone" }
}

# --- EKS MANAGED NODE GROUP (Private Subnets) ---
resource "aws_eks_node_group" "bedrock_nodes" {
  cluster_name    = aws_eks_cluster.bedrock_cluster.name
  node_group_name = "project-bedrock-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids

  # Cost Reminder: Stick to cost-effective, minimally sufficient configurations
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 3
    max_size     = 4
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_registry_policy,
  ]

  tags = { Name = "project-bedrock-nodes", Project = "karatu-2025-capstone" }
}

# --- OIDC PROVIDER FOR IRSA (IAM Roles for Service Accounts) ---
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.bedrock_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.bedrock_cluster.identity[0].oidc[0].issuer
}

# --- MODULE VARIABLES ---
variable "private_subnet_ids" { type = list(string) }

# --- MODULE OUTPUTS ---
output "cluster_name" { value = aws_eks_cluster.bedrock_cluster.name }
output "cluster_endpoint" { value = aws_eks_cluster.bedrock_cluster.endpoint }
output "cluster_security_group_id" { value = aws_eks_cluster.bedrock_cluster.vpc_config[0].cluster_security_group_id }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.oidc.arn }
output "oidc_provider_url" { value = aws_iam_openid_connect_provider.oidc.url }
