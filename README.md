# Project Bedrock — Cloud Infrastructure Capstone

An enterprise-grade, decoupled web application infrastructure designed for high availability, fault tolerance, and secure data state management. This project externalizes a multi-service retail application's state layers from ephemeral in-cluster containers to managed AWS production database environments, fully orchestrated using Infrastructure as Code (IaC) and validated via automated CI/CD.

## 🏗️ Architecture Overview

The system transitions the core application microservices away from localized database containers into hardened AWS native components:
* **Catalog Service:** Backed by an Amazon RDS MySQL Instance.
* **Orders Service:** Backed by an Amazon RDS PostgreSQL Instance.
* **Carts Service:** Backed by an Amazon DynamoDB NoSQL Table.
* **Compute Orchestration:** Hosted via high-availability Amazon EKS (Elastic Kubernetes Service) clusters managed under custom Kubernetes namespaces.

---

## 📂 Project Structure

```text
├── .github/workflows/
│   └── terraform.yml       # Automated CI Validation Pipeline (Lint & Validate)
├── k8s/
│   ├── catalog-configmap.yaml # Decoupled MySQL Production Endpoints
│   ├── orders-configmap.yaml  # Decoupled PostgreSQL Production Endpoints
│   └── carts-configmap.yaml   # Decoupled DynamoDB Production Configuration
├── lambda/                 # Serverless auxiliary computing microservices
└── terraform/              # Infrastructure as Code (IaC) Provisioning Modules

🚀 Deployment Instructions
1. Infrastructure Provisioning (Terraform)
Navigate to the infrastructure directory and initialize the provider:
cd terraform/
terraform init
terraform validate
terraform apply -auto-approve

2. Application Configuration & Orchestration (Kubernetes)
Ensure your context is set to your active Amazon EKS cluster, then apply the configurations:

Bash


cd ../k8s/
kubectl apply -f catalog-configmap.yaml
kubectl apply -f orders-configmap.yaml
kubectl apply -f carts-configmap.yaml
🛠️ CI/CD Automation
This repository utilizes GitHub Actions for continuous integration testing. Every push or pull request to the main branch triggers an isolated pipeline worker that performs:

Code Checkout validation.

Terraform format checking (terraform fmt -check).

Syntactic validation checks (terraform validate).
