output "cluster_endpoint" {
  value       = module.compute.cluster_endpoint
  description = "EKS Cluster API endpoint."
}

output "cluster_name" {
  value       = module.compute.cluster_name
  description = "EKS Cluster Name."
}

output "region" {
  value       = var.aws_region
  description = "AWS Deployment Region."
}

output "vpc_id" {
  value       = module.networking.vpc_id
  description = "The Provisioned VPC ID."
}

output "assets_bucket_name" {
  value       = "bedrock-assets-${var.student_id}"
  description = "Target Marketing Asset Bucket Name."
}

output "assets_bucket_name" {
  description = "The name of the secure assets S3 bucket"
  value       = aws_s3_bucket.assets.id
}
