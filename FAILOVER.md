# Failover and Disaster Recovery Documentation

## Table of Contents

- [Overview](#overview)
- [Automatic Failover Capabilities](#automatic-failover-capabilities)
- [High Availability Architecture](#high-availability-architecture)
- [Failover Scenarios](#failover-scenarios)
- [Manual Intervention Procedures](#manual-intervention-procedures)

## Overview

The Infrastructure is designed with **high availability** and **automatic failover** as core principles. The architecture leverages Azure's availability zones, load balancing, and health monitoring to ensure continuous service availability.

### Failover Summary

| Scenario | Detection Time | Failover Time | Automatic | User Impact |
|----------|---------------|---------------|-----------|-------------|
| **VM Instance Failure** | 30 seconds | Instant | ✅ Yes | None - traffic routes to healthy instances |
| **Availability Zone Failure** | 30 seconds | Instant | ✅ Yes | None - traffic routes to other zones |
| **Database Failure** | 15-30 seconds | 2-5 minutes | ⚠️ Auto-restart | Brief interruption during restart |
| **Application Hang** | 30 seconds | Instant | ✅ Yes | None - instance removed from pool |

### Key Infrastructure Components

**Current Deployment**

- **Load Balancer**: `ivan-test-project-lb` (Zone-redundant, Standard SKU)
- **Public IP**: `4.254.65.150` (from the deployment) - will be different each fresh rebuild
- **VMSS**: `ivan-test-project-vmss` (3 instances across zones 1, 2, 3)
- **Backend Pool**: 3 instances
  - Instance 0: Zone 2, IP 10.0.1.4
  - Instance 1: Zone 3, IP 10.0.1.5
  - Instance 2: Zone 1, IP 10.0.1.6
- **Database**: `ivan-test-project-pg-flex` (PostgreSQL 16)
- **Health Probe**: HTTP:80/health.html (15-second interval)

<img width="2113" height="1230" alt="image" src="https://github.com/user-attachments/assets/ed88f5d6-1046-483b-bcf0-a032563b184e" />


## Automatic Failover Capabilities

### 1. VM Instance Failure

**What Triggers It**:
- Hardware failure (host/disk failure)
- OS crash or kernel panic
- Application hang (Nginx stops responding)
- Memory exhaustion
- Process crash

**Automatic Response**:

```
T+0s:   Instance becomes unresponsive
T+15s:  First health probe fails (HTTP timeout or non-200 status)
T+30s:  Second health probe fails (unhealthy threshold reached)
T+30s:  Load balancer removes instance from backend pool
        → No new connections sent to failed instance
        → Existing connections may drop
        → Traffic redistributed to 2 healthy instances (66% capacity)
T+5m:   If CPU > 75% on remaining instances, auto-scaler triggers
T+10m:  New instance provisioned (takes load off remaining instances)
T+30m:  Auto-repair grace period expires
T+30m:  Failed instance deleted and replaced
T+33m:  Replacement instance healthy and added to backend pool
```

**Impact**:
- ✅ **Zero downtime** - Load balancer routes to healthy instances
- ✅ **No data loss** - Web tier is stateless
- ⚠️ **Reduced capacity** - Temporarily 2 instead of 3 instances
- ⚠️ **Slight performance impact** - Higher load on remaining instances

<img width="1391" height="671" alt="image" src="https://github.com/user-attachments/assets/bb05c31f-b5dd-4bfe-97f7-0500f392686d" />

<img width="1297" height="783" alt="image" src="https://github.com/user-attachments/assets/f8fcc68b-e54a-42dc-9d55-c1d748c91efb" />

<img width="1256" height="1093" alt="image" src="https://github.com/user-attachments/assets/269bef26-22d1-4c5e-8624-2e47a85d2304" />


### 2. Availability Zone Failure

**What Triggers It**:
- Datacenter power outage
- Network connectivity loss
- Multiple simultaneous host failures in a zone
- Azure platform issue affecting entire zone

**Current Zone Distribution**:
```
Zone 1: 1 instance (33% capacity)
Zone 2: 1 instance (33% capacity)
Zone 3: 1 instance (33% capacity)
```

**Automatic Response (Example: Zone 2 Fails)**:

```
T+0s:   Zone 2 loses connectivity
        → Instance 0 (10.0.1.4) becomes unreachable
T+15s:  First health probe fails for Zone 2 instance
T+30s:  Second health probe fails
T+30s:  Load balancer removes Zone 2 instance from pool
        → 100% traffic now to Zone 1 & Zone 3
        → Capacity reduced to 66%
T+5m:   Auto-scaler detects high CPU (>75%)
T+10m:  Auto-scaler provisions new instances in Zone 1 & Zone 3
        → Scales from 2 to 4 instances (maintaining zone balance)
T+30m:  Auto-repair attempts to replace Zone 2 instance
        → If zone still unavailable, instance created in healthy zone
T+??:   When Zone 2 recovers, new instances can be created there
        → VMSS gradually rebalances across all 3 zones
```

**Impact**:
- ✅ **Zero downtime** - Automatic failover to healthy zones
- ✅ **No data loss**
- ⚠️ **33% capacity loss** initially
- ✅ **Auto-recovery** - Scales out to compensate

### 3. Database Failure

**What Triggers It**:
- PostgreSQL process crash
- Storage I/O errors
- Memory exhaustion
- Connection limit reached
- Corruption or deadlock

**Automatic Response**:

```
T+0s:   Database becomes unresponsive
        → Application starts throwing errors
        → HTTP 500 errors to clients
T+30s:  Azure detects database health issue
T+1m:   Azure attempts automatic restart
T+2-5m: Database service restarts
        → All connections dropped
        → Connection pool reinitializes
T+5m:   Database accepting connections again
        → Application recovers automatically
```

**Impact**:
- ❌ **Downtime**: 2-5 minutes during restart
- ✅ **No data loss**: 7-day automated backups + transaction logs
- ⚠️ **Connection storm**: Many clients reconnect simultaneously

**Database Backup Configuration**:
- **Type**: Continuous (transaction log streaming)
- **Retention**: 7 days
- **Point-in-Time Restore**: Any second within retention window
- **Geo-Redundant**: Not enabled (single region)

## High Availability Architecture

### Multi-Zone Deployment

**Azure Availability Zones** are physically separate locations within the Australia East region:

```
┌────────────────── AUSTRALIA EAST REGION ──────────────────┐
│                                                             │
│  ┌───────────┐      ┌───────────┐      ┌───────────┐     │
│  │  ZONE 1   │      │  ZONE 2   │      │  ZONE 3   │     │
│  │           │      │           │      │           │     │
│  │ Instance 2│      │ Instance 0│      │ Instance 1│     │
│  │ 10.0.1.6  │      │ 10.0.1.4  │      │ 10.0.1.5  │     │
│  │           │      │           │      │           │     │
│  │ [Separate │      │ [Separate │      │ [Separate │     │
│  │  Power]   │      │  Power]   │      │  Power]   │     │
│  │ [Separate │      │ [Separate │      │ [Separate │     │
│  │  Network] │      │  Network] │      │  Network] │     │
│  └─────┬─────┘      └─────┬─────┘      └─────┬─────┘     │
│        │                  │                  │            │
│        └──────────────────┼──────────────────┘            │
│                           │                               │
└───────────────────────────┼───────────────────────────────┘
                            │
                  ┌─────────▼─────────┐
                  │  Load Balancer    │
                  │  (Zone-Redundant) │
                  │  4.254.65.150     │
                  └─────────┬─────────┘
                            │
                         Internet
```

### Health Monitoring

**Load Balancer Health Probe**:
- **Name**: `http-probe`
- **Protocol**: HTTP
- **Port**: 80
- **Path**: `/health.html`
- **Interval**: 15 seconds
- **Unhealthy Threshold**: 2 consecutive failures (30 seconds)

**Health Check Content**:
```
GET /health.html HTTP/1.1
Host: 10.0.1.x

Response:
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 2

OK
```

**Instance States**:
- **Healthy**: Returns HTTP 200 → Receives traffic
- **Degraded**: 1 failure → Still receives traffic (grace period)
- **Unhealthy**: 2+ failures → Removed from backend pool
- **Unknown**: Can't reach instance → Treated as unhealthy

## Failover Scenarios

### Scenario 1: Single Instance Becomes Unresponsive

**Real-World Example**:

Current deployment has 3 instances. Let's say Instance 0 in Zone 2 experiences a problem.

**Before Failure**:
```
Zone 1: Instance 2 (10.0.1.6) - 33% traffic
Zone 2: Instance 0 (10.0.1.4) - 33% traffic ← FAILS
Zone 3: Instance 1 (10.0.1.5) - 33% traffic
```

**During Failure (T+30s)**:
```
Zone 1: Instance 2 (10.0.1.6) - 50% traffic
Zone 2: Instance 0 (10.0.1.4) - REMOVED
Zone 3: Instance 1 (10.0.1.5) - 50% traffic
```

**After Auto-Repair (T+30m)**:
```
Zone 1: Instance 2 (10.0.1.6) - 33% traffic
Zone 2: Instance 3 (10.0.1.7) - 33% traffic (new instance)
Zone 3: Instance 1 (10.0.1.5) - 33% traffic
```

**What You'd See**:
```bash
# At T+1m (one instance unhealthy)
$ curl http://4.254.65.150
<html>...Hello from Azure!...</html>  # Still works

$ az vmss list-instances --name ivan-test-project-vmss --resource-group ivan-test-project-rg --output table
InstanceId  ProvisioningState  Location      Zone
----------  -----------------  ------------  ----
0           Failed             australiaeast  2     ← Problem instance
1           Succeeded          australiaeast  3
2           Succeeded          australiaeast  1
```

### Scenario 2: Complete Zone Outage

**Trigger**: Azure Zone 2 loses power

**Impact**: All instances in Zone 2 become unavailable immediately

**Automatic Response Timeline**:

**T+0 to T+30s** (Detection):
- Health probes fail for Zone 2 instances
- Load balancer marks them unhealthy
- Traffic redirects to Zone 1 & 3

**T+30s to T+5m** (Operating Degraded):
- 2 instances handle 100% of traffic
- CPU usage increases on remaining instances
- Application continues functioning

**T+5m to T+10m** (Auto-Scaling):
- Auto-scaler detects average CPU > 75%
- Provisions new instances in Zone 1 & Zone 3
- Gradually returns to full capacity

**T+30m+** (Auto-Repair):
- Failed Zone 2 instances deleted
- Replaced with instances in healthy zones
- Zone balance maintained across available zones

## Manual Intervention Procedures

### Procedure 1: Force Instance Replacement

**When to Use**: Instance stuck, not auto-repairing, or suspected compromise

```bash
# 1. Identify problematic instance
az vmss list-instances \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --output table

# 2. Delete specific instance (automatically recreated)
az vmss delete-instances \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --instance-ids 0

# 3. Monitor replacement
watch -n 10 'az vmss list-instances \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --query "[].{ID:instanceId, State:provisioningState, Zone:zones[0]}" \
  --output table'

# 4. Verify health after replacement (2-3 minutes)
curl http://4.254.65.150/health.html
```

**Expected Result**: New instance created in same zone, healthy within 3-5 minutes

### Procedure 2: Emergency Scale-Out

**When to Use**: Unexpected traffic spike, DDoS, or performance issues

```bash
# 1. Check current capacity
az vmss show \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --query "sku.capacity" -o tsv

# 2. Scale to maximum capacity immediately
az vmss scale \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --new-capacity 10

# 3. Monitor scaling progress
az vmss list-instances \
  --name ivan-test-project-vmss \
  --resource-group ivan-test-project-rg \
  --query "[].{Instance:instanceId, State:provisioningState, Zone:zones[0]}" \
  --output table

# 4. Verify all instances healthy
az network lb show \
  --name ivan-test-project-lb \
  --resource-group ivan-test-project-rg \
  --query "backendAddressPools[0].backendIPConfigurations[].id" | grep -c "ipConfigurations"
```

**Expected Result**: 10 instances provisioned within 5-10 minutes, distributed across zones

### Procedure 3: Database Point-in-Time Restore

**When to Use**: Data corruption, accidental deletion, ransomware attack

```bash
# 1. Identify restore point (UTC time)
RESTORE_TIME="2025-11-07T10:00:00Z"  # Before the incident

# 2. Create new database from backup
az postgres flexible-server restore \
  --resource-group ivan-test-project-rg \
  --name ivan-test-project-pg-flex-restored \
  --source-server ivan-test-project-pg-flex \
  --restore-time "$RESTORE_TIME"

# 3. Wait for restore to complete (15-30 minutes)
az postgres flexible-server show \
  --resource-group ivan-test-project-rg \
  --name ivan-test-project-pg-flex-restored \
  --query "state" -o tsv
# Wait until shows "Ready"

# 4. Verify data in restored database
psql -h ivan-test-project-pg-flex-restored.private.postgres.database.azure.com \
     -U sqladmin -d webapp_db \
     -c "SELECT COUNT(*) FROM your_critical_table;"

# 5. Update application to use restored database
# (Requires Terraform change or connection string update)
```

**Expected Result**: New database with data as of specified restore point


### Pipelines 
<img width="620" height="443" alt="image" src="https://github.com/user-attachments/assets/99ea9486-89ff-4ebb-8daf-3d16a51e7423" />

<img width="1719" height="838" alt="image" src="https://github.com/user-attachments/assets/15a153be-26d2-4529-87a1-1e64e5ad7634" />

### Branch protection
<img width="1864" height="826" alt="image" src="https://github.com/user-attachments/assets/b41545e8-f1f3-48e0-8dc9-22335655c35c" />

