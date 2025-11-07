#  Platform Infrastructure

> **Enterprise-grade Azure Infrastructure with Automated Failover and High Availability**

[![Terraform](https://img.shields.io/badge/Terraform-1.9.8-623CE4?logo=terraform)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-Azure%20DevOps-0078D7?logo=azure-devops)](https://dev.azure.com/)

##  Overview

This repository contains the complete Infrastructure as Code (IaC) implementation for a highly available, auto-scaling web application platform on Microsoft Azure. The infrastructure is designed for reliability, scalability, and automated disaster recovery.

###  Key Features

- ** Automated Failover**: Zone-redundant architecture with automatic instance recovery
- ** Auto-Scaling**: CPU-based scaling from 3 to 10 instances
- ** Secure by Default**: Private database, NSG rules, and isolated subnets
- ** CI/CD Ready**: Automated deployment via Azure DevOps pipelines
- ** State Management**: Remote state in Azure Storage with locking
- ** Multi-Zone**: Resources distributed across 3 availability zones

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Traffic                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Public IP      │
                    │  (Zone Redundant)│
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Load Balancer  │
                    │  (Standard SKU) │
                    │  Health Probe:  │
                    │  /health.html   │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
       ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
       │ VMSS    │     │ VMSS    │     │ VMSS    │
       │ Zone 1  │     │ Zone 2  │     │ Zone 3  │
       │ (Nginx) │     │ (Nginx) │     │ (Nginx) │
       └────┬────┘     └────┬────┘     └────┬────┘
            │                │                │
            └────────────────┼────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Virtual Network│
                    │  10.0.0.0/16    │
                    ├─────────────────┤
                    │ Web Subnet      │
                    │ 10.0.1.0/24     │
                    ├─────────────────┤
                    │ Database Subnet │
                    │ 10.0.2.0/24     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ PostgreSQL Flex │
                    │ (Private)       │
                    │ Private DNS Zone│
                    └─────────────────┘
```

### Infrastructure Components

| Component | Purpose | High Availability |
|-----------|---------|-------------------|
| **Load Balancer** | Traffic distribution | Zone-redundant Public IP |
| **VMSS** | Web application hosting | 3 zones, auto-repair enabled |
| **PostgreSQL Flexible Server** | Database | Automated backups (7 days) |
| **Virtual Network** | Network isolation | Multi-subnet architecture |
| **NSG** | Security rules | Allows HTTP/HTTPS only |
| **Private DNS** | Database name resolution | VNet-linked |
| **Autoscale** | Dynamic capacity | CPU-based (25-75% threshold) |

## Quick Start

### Prerequisites

- Azure subscription with appropriate permissions
- Azure DevOps organization and project
- Service Principal with Contributor role
- Self-hosted Azure DevOps agent (for pipelines)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/bss-platform-infrastructure.git
   cd bss-platform-infrastructure
   ```

2. **Configure backend storage** (one-time setup)
   ```bash
   # Create storage account for Terraform state
   az group create --name tfstate-rg --location australiaeast
   az storage account create --name tfstatestorageivan \
     --resource-group tfstate-rg --location australiaeast \
     --sku Standard_LRS
   az storage container create --name tfstate \
     --account-name tfstatestorageivan
   ```

3. **Set up Azure DevOps variables**
   
   Navigate to Azure DevOps → Pipelines → Library → Variable Groups
   
   Create group: `terraform-secrets`
   
   Add variables:
   - `servicePrincipalId` (Service Principal App ID)
   - `servicePrincipalKey` (Service Principal Secret) - **Mark as secret**
   - `subscriptionId` (Azure Subscription ID)
   - `tenantId` (Azure AD Tenant ID)
   - `admin_password` (VM admin password) - **Mark as secret**
   - `db_admin_password` (Database password) - **Mark as secret**

4. **Run the pipeline**
   
   - Push to any branch → Runs Terraform Plan
   - Push to `main` branch → Runs Terraform Plan + Apply

##  Repository Structure

```
infrastructure-automation/
├── terraform/                    # Terraform configuration files
│   ├── backend.tf               # Remote state configuration
│   ├── provider.tf              # Azure provider and resource group
│   ├── variables.tf             # Variable definitions
│   ├── main.tf                  # Common locals and tags
│   ├── network.tf               # VNet, subnets, NSG
│   ├── loadbalancer.tf          # Load balancer and health probes
│   ├── vms.tf                   # VMSS and autoscaling
│   ├── database.tf              # PostgreSQL Flexible Server
│   ├── outputs.tf               # Output values
│   └── terraform.tfvars.example # Example variables file
├── pipelines/                   # Azure DevOps pipelines
│   ├── azure-pipelines.yml      # Main deployment pipeline
│   └── tf-destroy-pipeline.yml  # Cleanup/destroy pipeline
└── README.md                    # This file
│ 
└── FAILOVER.md                   
```

##  Security Considerations

- ✅ **Database**: Private endpoint, no public access
- ✅ **Secrets**: Stored in Azure DevOps variable groups (encrypted)
- ✅ **Network**: NSG rules restrict traffic to HTTP/HTTPS
- ✅ **Authentication**: Service Principal with minimal required permissions
- ✅ **State File**: Stored in Azure Storage with encryption at rest

##  Deployment Workflow

1. **Feature branches**: Create PR → Pipeline runs `terraform plan` → Review changes
2. **Main branch**: Merge → Pipeline runs `terraform plan` + `terraform apply`
3. **Destroy**: Manually trigger `tf-destroy-pipeline.yml` (requires approval)

## Key Metrics & Monitoring

Based on deployed infrastructure:

| Metric | Configuration |
|--------|---------------|
| **VM Instances** | Min: 3, Max: 10, Default: 3 |
| **Scale Out** | CPU > 75% for 5 minutes → +1 instance |
| **Scale In** | CPU < 25% for 10 minutes → -1 instance |
| **Health Check** | Every 15 seconds on `/health.html` |
| **Auto-Repair** | Enabled with 30-minute grace period |
| **Backup Retention** | 7 days for PostgreSQL |
| **Availability Zones** | 3 zones with balanced distribution |

## Failover Capabilities

### Automatic Failover Scenarios

1. **VM Instance Failure**
   - Health probe fails → Instance removed from load balancer
   - Auto-repair replaces unhealthy instance within 30 minutes
   
2. **Zone Failure**
   - Traffic automatically routes to healthy zones
   - VMSS rebalances instances across remaining zones

3. **High Load**
   - CPU exceeds 75% → New instances added
   - Cooldown period prevents flapping

See **[FAILOVER.md](docs/FAILOVER.md)** for detailed failover procedures and disaster recovery plans.

## 🛠️ Common Operations

### View Application
```bash
# Get the public IP
cd terraform
terraform output application_url
```

### Scale Manually
```bash
# Via Azure CLI
az vmss scale --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --new-capacity 5
```

### Check Health Status
```bash
# Check load balancer backend pool health
az network lb show --name ivan-test-project-lb \
  --resource-group ivan-test-project-rg \
  --query "backendAddressPools[0].backendIPConfigurations[].id" -o table
```

### Access Database
```bash
# Connect via private endpoint (from within VNet)
psql -h ivan-test-project-pg-flex.private.postgres.database.azure.com \
     -U sqladmin -d webapp_db
```

##  Testing the Infrastructure

### Load Testing
```bash
# Generate load to trigger autoscaling
ab -n 10000 -c 100 http://$(terraform output -raw load_balancer_ip)/
```

### Failover Testing
```bash
# Simulate instance failure
az vmss restart --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --instance-id 0
```

## 💰 Cost Optimization

Current configuration estimated costs (Australia East):

- **Load Balancer**: ~$20/month
- **VMSS (3x B1ms)**: ~$45/month
- **PostgreSQL Flexible (B1ms)**: ~$15/month
- **Storage**: ~$2/month
- **Networking**: ~$5/month

**Total**: ~$87/month (varies with autoscaling)

### Cost Reduction Tips
- Reduce VMSS instance count during off-hours
- Use Azure Reservations for predictable workloads
- Enable Azure Hybrid Benefit if applicable
