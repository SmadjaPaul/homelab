# Oracle Cloud Always Free Tier - Complete Reference

This document lists all Oracle Cloud Always Free tier resources.
Last updated: 2026-01-29

Source: https://www.oracle.com/cloud/free/

## Compute

| Resource | Always Free Limit | Notes |
|----------|-------------------|-------|
| **ARM (Ampere A1)** | 4 OCPUs, 24 GB RAM | 3,000 OCPU hours + 18,000 GB hours/month |
| **AMD (E2.1.Micro)** | 2 VMs | 1/8 OCPU + 1 GB RAM each |

### Our Usage (Planned)

| VM | OCPUs | RAM | Storage | Type |
|----|-------|-----|---------|------|
| oci-mgmt | 1 | 6 GB | 50 GB | ARM |
| oci-node-1 | 2 | 12 GB | 64 GB | ARM |
| oci-node-2 | 1 | 6 GB | 75 GB | ARM |
| **Total** | **4** | **24 GB** | **189 GB** | ✅ Within limits |

## Storage

| Resource | Always Free Limit |
|----------|-------------------|
| Block Volume | 200 GB total (2 volumes) |
| Block Volume Backups | 5 backups |
| Object Storage | 20 GB (Standard + Infrequent + Archive) |
| Archive Storage | Included in 20 GB Object Storage |

### Our Object Storage Usage (Velero Backups)

| Bucket | Max Size | Purpose |
|--------|----------|---------|
| homelab-velero-backups | 10 GB | Kubernetes backups |
| **Reserved** | 10 GB | Future use |
| **Total** | **20 GB** | ✅ Within limits |

**Lifecycle Policy:**
- Backups archived after 7 days (cheaper storage)
- Backups deleted after 14 days (stay within quota)

## Networking

| Resource | Always Free Limit |
|----------|-------------------|
| VCNs | 2 (with IPv4/IPv6) |
| Load Balancer (Flexible) | 1 instance, 10 Mbps |
| Network Load Balancer | 1 instance |
| Outbound Data Transfer | 10 TB/month |
| VPN Connections | 50 IPSec |
| VCN Flow Logs | 10 GB/month |
| Service Connector Hub | 2 connectors |

## Databases

| Resource | Always Free Limit |
|----------|-------------------|
| Autonomous Database | 2 (ATP, ADW, JSON, or APEX) |
| HeatWave | 1 instance + 50 GB storage |
| NoSQL | 25 GB per table, up to 3 tables |

## Security

| Resource | Always Free Limit |
|----------|-------------------|
| Bastions | 5 |
| Vault Keys (HSM) | 20 key versions |
| Vault Secrets | 150 |
| Private CAs | 5 |
| TLS Certificates | 150 |

## Observability & Management

| Resource | Always Free Limit |
|----------|-------------------|
| Logging | 10 GB/month |
| Monitoring | 500M ingestion datapoints |
| APM | 1,000 tracing events/hour |
| Notifications (HTTPS) | 1M/month |
| Notifications (Email) | 1,000/month |
| Email Delivery | 100 emails/day |
| Console Dashboards | 100 |

## Developer Services

| Resource | Always Free Limit |
|----------|-------------------|
| APEX | 744 hours/instance |

## Cost Monitoring

To avoid charges:

1. **Set Budget Alerts**:
   - OCI Console → Governance → Budgets → Create Budget
   - Set threshold: $1 (any spending = alert)

2. **Monitor Usage**:
   - OCI Console → Governance → Limits, Quotas and Usage
   - Check "Service Limits" tab

3. **Resource Tagging**:
   - Tag all resources with `Project = homelab`
   - Filter by tag in Cost Analysis

## Important Notes

1. **Region Lock**: Always Free resources are only available in your **home region**
2. **Capacity**: ARM shapes may show "Out of capacity" - try different availability domains or times
3. **30-Day Trial**: $300 credit expires after 30 days, then reverts to Always Free
4. **No Credit Card Charges**: After trial, you won't be charged - resources just stop working if you exceed limits

## Terraform Validation

Our Terraform configuration includes automatic quota validation:

```hcl
# terraform/oracle-cloud/quota-validation.tf
# Fails if planned resources exceed free tier limits
```

Run `terraform plan` to see quota status:

```bash
terraform plan
# Shows: quota_status.usage with percentages
```
