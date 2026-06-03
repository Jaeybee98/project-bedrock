module "networking" {
  source   = "./modules/networking"
  vpc_cidr = var.vpc_cidr
  azs      = var.availability_zones
}

module "compute" {
  source             = "./modules/compute"
  private_subnet_ids = module.networking.private_subnet_ids
}

module "storage" {
  source               = "./modules/storage"
  vpc_id               = module.networking.vpc_id
  eks_cluster_sg_id    = module.compute.cluster_security_group_id
  db_subnet_group_name = module.networking.database_subnet_group_name
  student_id           = var.student_id
}

module "monitoring" {
  source            = "./modules/monitoring"
  cluster_name      = module.compute.cluster_name
  oidc_provider_arn = module.compute.oidc_provider_arn
  oidc_provider_url = module.compute.oidc_provider_url
}

# Native Kubernetes connection configurations mapping
data "aws_eks_cluster_auth" "cluster" {
  name = module.compute.cluster_name
}

provider "kubernetes" {
    host                   = module.compute.cluster_endpoint
    cluster_ca_certificate = base64decode(module.compute.cluster_certificate_authority_data)

    # FIXED: Dynamically fetch short-lived tokens directly using the AWS CLI
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.compute.cluster_name]
      command     = "aws"
    }
  }

provider "helm" {
  kubernetes {
    host                   = module.compute.cluster_endpoint
    cluster_ca_certificate = base64decode(module.compute.cluster_certificate_authority_data)

    # FIXED: Dynamically fetch short-lived tokens directly using the AWS CLI
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.compute.cluster_name]
      command     = "aws"
    }
  }
}

# Automated Helm chart install of the AWS Load Balancer controller
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.compute.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.monitoring.alb_controller_role_arn
  }
  
  set {
    name  = "region"
    value = "us-east-1"
  }
  
  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  depends_on = [module.compute]
}
