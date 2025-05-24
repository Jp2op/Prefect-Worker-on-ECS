# Prefect Worker Deployment on Amazon ECS using Terraform

## 📌 Purpose

This repository contains Infrastructure as Code (IaC) using **Terraform** to deploy a **Prefect worker** on **Amazon ECS Fargate**. The goal is to demonstrate proficiency in designing scalable cloud infrastructure, container orchestration, and automation with Prefect Cloud.

This was created as part of a DevOps internship assignment.

---

## ⚙️ Tooling & Stack

- **IaC Tool**: Terraform (`>= 1.2.0`)
- **Cloud Provider**: AWS (ECS Fargate, VPC, IAM, CloudWatch, Secrets Manager)
- **Workflow Orchestration**: Prefect Cloud
- **Container**: `prefecthq/prefect:2-latest`

---

## 📁 Repository Structure

```
.
├── main.tf                 # Core infrastructure and ECS setup
├── variables.tf            # Input variables
├── outputs.tf              # Outputs (ECS cluster ARN etc.)
├── secrets.tf              # Secrets Manager integration
├── terraform.tfvars        # Optional: values for your variables
├── README.md               # This file
├── report.md               # Detailed report (see separate deliverable)
```

---

## 🚀 Deployment Instructions

### 1. ✅ Prerequisites

- AWS account with required permissions
- Terraform CLI (`>= 1.2.0`)
- AWS CLI configured with credentials (`aws configure`)
- Prefect Cloud account
- Prefect API key (saved in Secrets Manager)

---

### 2. 🌐 Setup Variables

Update `terraform.tfvars` or set the following variables:

```hcl
region              = "us-east-1"
prefect_api_key     = "<your-prefect-api-key>"
prefect_account_id  = "<your-prefect-account-id>"
prefect_workspace_id = "<your-prefect-workspace-id>"
work_pool_name      = "ecs-work-pool"
```

Alternatively, use environment variables or CLI `-var` flags.

---

### 3. 🏗 Deploy Infrastructure

```bash
terraform init
terraform apply
```

Terraform will:
- Create a VPC with 3 public & 3 private subnets
- Deploy ECS Cluster (`prefect-cluster`)
- Create IAM roles and security groups
- Register a Prefect worker as an ECS service
- Set up logging and secrets integration

---

## 🔍 Verification Steps

1. Open **AWS Console** → ECS → `prefect-cluster`
   - Confirm the **service** `dev-worker` is running
   - Inspect logs in **CloudWatch Logs** `/ecs/prefect-worker`

2. Open **Prefect Cloud**:
   - Check if the `ecs-work-pool` is registered
   - Logs should confirm connection to the Prefect API

> ⚠️ **Note**: On Prefect Cloud's **free tier**, only *Push* work pools (type: `prefect:managed`) are supported.  
> **Pull-based workers** like this ECS setup require a **paid plan**.  
> Therefore, while the worker runs and connects, it cannot poll for flow runs under the free plan.  
> See: [Prefect Cloud Plans](https://www.prefect.io/pricing)

---

## 🧹 Cleanup Instructions

To destroy all provisioned infrastructure:

```bash
terraform destroy
```

Ensure ECS services and Secrets Manager entries are cleaned up if manually modified.

---

## 📦 Outputs

After deployment, Terraform will output:

- `ECS Cluster ARN`
- `VPC ID`
- `Worker service name`

---

## 🧠 Design Highlights

- Modular VPC using the `terraform-aws-modules/vpc` module
- NAT Gateway for private subnet internet access
- ECS Fargate task with custom logging and secret injection
- IAM role with scoped Secrets Manager access
---

## 🧑‍💻 Author

Submitted Jp for the DevOps Internship Assignment.

---
