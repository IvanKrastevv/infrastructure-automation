⚙️ 2️⃣ Prepare Azure Environment
Step 1. Log in to Azure
az login
az account list -o table
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

Step 2. Create Service Principal for Azure DevOps

This allows your Azure DevOps pipeline to authenticate into your subscription securely.

az ad sp create-for-rbac \
  --name "tf-sp-iac-demo" \
  --role="Contributor" \
  --scopes="/subscriptions/<YOUR_SUBSCRIPTION_ID>" \
  --sdk-auth


Output (save it somewhere safe):

{
  "clientId": "xxxx",
  "clientSecret": "xxxx",
  "subscriptionId": "xxxx",
  "tenantId": "xxxx",
  ...
}


You’ll paste this into Azure DevOps later.


Step 3. Create Terraform State Storage

Terraform needs a remote backend to store state:

az group create -n tfstate-rg -l westeurope
az storage account create -n <uniquestateaccount> -g tfstate-rg -l westeurope --sku Standard_LRS
az storage container create -n tfstate --account-name <uniquestateaccount>


🧠 5️⃣ Connect Azure DevOps to Azure

In Azure DevOps:

Go to Project Settings → Service connections

Choose Azure Resource Manager → Service principal (manual)

Paste the JSON output from your az ad sp create-for-rbac command

Name it: tf-sp-iac-demo

Click Verify and Save

✅ 6️⃣ Run the Pipeline

Commit all files to GitHub.

In Azure DevOps → Pipelines → New pipeline → Connect GitHub → pick repo.

Choose Existing YAML and select your azure-pipelines.yml.

Click Run.

Terraform will:

Create RG, VNet, Subnet

Deploy Load Balancer + 2 Nginx VMs (auto-healing)

Provision Azure SQL Database

🧩 7️⃣ Verify

After a successful run:

Outputs:
lb_ip = 20.x.x.x
db_fqdn = iacdemo-sql.database.windows.net


🌐 Visit http://<lb_ip> → should show “Hello from <hostname>”.

🗄️ Connect to DB via Azure Data Studio using:

Server: <db_fqdn>

Username: sqladmin

Password: (from Terraform output)


🧯 Failover & Auto-Healing Strategy (README Section)
💡 Overview

In this infrastructure, failover and auto-healing mechanisms are implemented to ensure high availability (HA) and resilience of the deployed web application stack.
The design ensures that if one or more components of the system fail (for example, a VM instance crash, network failure, or region issue), traffic and workloads are automatically redirected or recovered with minimal downtime — without manual intervention.

🧱 1️⃣ Web Tier — VM Scale Set + Load Balancer

Components involved:

azurerm_linux_virtual_machine_scale_set (VMSS)

azurerm_lb (Load Balancer)

azurerm_lb_probe (Health Probe)

✅ How Failover Works

The Azure Load Balancer monitors each VM instance in the scale set using the configured HTTP health probe (/healthz endpoint).
If an instance becomes unhealthy (fails to respond within probe interval):

The LB automatically stops routing traffic to that VM.

The VM Scale Set detects that the instance is in a failed state (e.g., crashed or unresponsive).

Azure automatically recreates or restarts the instance from the original image and configuration (defined in Terraform).

When the new VM passes the health check, the LB adds it back into the rotation.

This ensures continuous service availability — the traffic is failed over to healthy VMs instantly.

🔁 Auto-Healing

VM Scale Sets include an automatic repair policy that monitors the health of individual instances.
If an instance repeatedly fails health probes, Azure:

Marks it as unhealthy

Automatically deallocates and recreates the VM

Re-applies the same custom data (cloud-init.sh) during provisioning

This provides self-healing at the compute layer.

You can optionally enable explicit auto-healing policies in Terraform:

automatic_instance_repair {
  enabled      = true
  grace_period = "PT10M" # Wait 10 minutes before replacing unhealthy instances
}

🗄️ 2️⃣ Database Tier — Azure SQL Database

The database is hosted as a managed Azure SQL service, which provides:

Built-in automatic failover groups

Active geo-replication

99.99% availability SLA

Automatic patching, backup, and HA

When the primary database node becomes unavailable, Azure automatically promotes a replica to primary.
This failover is transparent to the application layer, meaning connection strings do not need manual updates.

If you want multi-region HA:

resource "azurerm_mssql_failover_group" "fg" {
  name                = "${var.prefix}-fg"
  server_id           = azurerm_mssql_server.sql.id
  partner_server_id   = azurerm_mssql_server.secondary.id
  databases           = [azurerm_mssql_database.appdb.id]
  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 5
  }
}

☁️ 3️⃣ Network Tier — Azure Load Balancer

At the network layer:

The Public Load Balancer provides multi-instance failover.

It continuously probes backend instances on port 80.

If one instance fails, the LB removes it from the backend pool automatically.

You can verify probe logic:

resource "azurerm_lb_probe" "http_probe" {
  protocol     = "Http"
  port         = 80
  request_path = "/healthz"
  interval_in_seconds = 15
  number_of_probes    = 2
}


This design guarantees no single point of failure in the web tier.

🔍 4️⃣ Monitoring, Alerts, and Self-Recovery (Optional but Recommended)

To improve observability and resilience:

Azure Monitor can track CPU, memory, and network utilization of VMSS instances.

Action Groups can trigger alerts or auto-healing runbooks in response to failures.

Application Insights or Log Analytics can be integrated to detect anomalies.

Example: Restart a VM automatically on failure using an Azure Automation Runbook.

🧪 5️⃣ Testing Failover (Chaos Engineering)

You can simulate a failure to validate your setup:

# SSH into one VM and stop nginx
sudo systemctl stop nginx

# Within a minute or two:
# - The health probe will mark it as unhealthy
# - LB stops routing traffic to it
# - VMSS auto-repairs it (restarts the instance)


Expected behavior:

The public LB continues to serve responses (from the remaining healthy VM)

The failed instance is automatically replaced

This validates end-to-end failover and self-healing.

🧠 Summary Diagram
                    ┌──────────────────────────────┐
                    │        Azure Load Balancer    │
                    │ (Health probes, traffic mgmt) │
                    └─────────────┬────────────────┘
                                  │
                ┌─────────────────┴─────────────────┐
                │                                   │
        ┌──────────────┐                   ┌──────────────┐
        │ VM Instance 1│                   │ VM Instance 2│
        │ Nginx + App  │                   │ Nginx + App  │
        └──────┬───────┘                   └──────┬───────┘
               │ Auto-Heal                              │
               └─────────────────────────────────────────┘
                          │
                          ▼
                  ┌────────────────┐
                  │ Azure SQL DB   │
                  │ (Managed HA)   │
                  └────────────────┘

⚙️ 6️⃣ Failover Lifecycle Summary
Layer	Detection	Recovery Action	Managed By
VM / App	Health Probe (HTTP 80)	Restart/Replace VM	Azure VMSS
Load Balancer	Probe timeout	Remove from backend pool	Azure LB
Database	Node/region failure	Promote replica	Azure SQL
Infra	Terraform drift	Re-provision on pipeline run	Terraform + CI/CD
🔄 CI/CD Auto-Recovery

If infrastructure drift or corruption occurs, rerunning the Azure DevOps pipeline automatically:

Re-applies Terraform configuration

Detects missing or misconfigured resources

Recreates them to restore expected state

This provides infrastructure-level self-healing through declarative IaC.

✅ In summary:

The environment is designed for self-recovery using Azure’s native HA features:

VM Scale Set handles web instance failover and healing

Azure SQL provides built-in high availability

Load Balancer ensures traffic continuity

Terraform + CI/CD enforce consistent state after recovery