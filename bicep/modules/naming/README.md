# Naming Helper Module

## Overview

This Bicep module generates standardized resource names following **Azure Cloud Adoption Framework (CAF)** naming conventions and best practices. It ensures consistency across all Azure resources in your deployments and enforces naming standards organization-wide.

## Features

- ✅ **CAF-Compliant**: Follows Microsoft's recommended naming conventions
- ✅ **50+ Resource Types**: Covers all common Azure resource types
- ✅ **Character Limits**: Automatically handles resource-specific character limits
- ✅ **Uniqueness**: Supports unique suffixes for globally unique resource names
- ✅ **Flexibility**: Optional organization prefix and instance numbering
- ✅ **Environment-Aware**: Built-in support for dev/qa/prod environments
- ✅ **Region Abbreviations**: Consistent regional naming
- ✅ **Well-Documented**: Comprehensive metadata and references

## Supported Resource Types

### Networking
- Virtual Networks (vnet)
- Subnets (no prefix per CAF)
- Network Security Groups (nsg)
- Network Interfaces (nic)
- Public IP Addresses (pip)
- Application Gateway (agw)
- Load Balancer (lb)
- Azure Bastion (bas)
- Private Endpoints (pe)
- Private DNS Zones (privatelink.*)

### Compute
- Virtual Machines (vm, Linux & Windows)
- App Service Plans (asp)
- Web Apps (app)
- Function Apps (func)
- Azure Kubernetes Service (aks)
- Container Registry (acr)

### Storage & Databases
- Storage Accounts (st)
- SQL Server (sql)
- SQL Database (sqldb)
- Cosmos DB (cosmos)
- Azure Cache for Redis (redis)

### Security & Identity
- Key Vault (kv)
- Managed Identity (id)

### Monitoring
- Log Analytics Workspace (law)
- Application Insights (appi)

### Integration & Messaging
- Service Bus Namespace (sb)
- Event Hub Namespace (evhns)
- API Management (apim)

### Management
- Resource Groups (rg)
- Recovery Services Vault (rsv)
- Automation Account (aa)

### Content Delivery
- Azure Front Door (fd)
- CDN Profile (cdnp)

## Usage

### Basic Example

```bicep
// Import the naming module
module naming 'modules/naming/main.bicep' = {
  name: 'naming-convention'
  params: {
    regionAbbreviation: 'cus'     // centralus
    environment: 'dev'
    workloadName: 'webapp'
  }
}

// Use the generated names
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: naming.outputs.keyVault
  location: location
  // ... rest of configuration
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: naming.outputs.webApp
  location: location
  // ... rest of configuration
}
```

### Advanced Example with Unique Suffix

```bicep
// Generate unique suffix for globally unique resources
var uniqueSuffix = uniqueString(resourceGroup().id)

module naming 'modules/naming/main.bicep' = {
  name: 'naming-convention'
  params: {
    regionAbbreviation: 'eus'
    environment: 'prod'
    workloadName: 'webapp'
    uniqueSuffix: uniqueSuffix      // Ensures global uniqueness
    orgPrefix: 'contoso'             // Organization prefix
    instance: 1                      // Instance number for multi-instance resources
  }
}

// Generated names include unique suffix
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: naming.outputs.storageAccount  // e.g., contoso-steusproductsabcd1234
  location: location
  // ... rest of configuration
}
```

### Multi-Instance Resources

```bicep
// Deploy multiple VMs with consistent naming
@batchSize(1)
resource vms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(1, 3): {
  name: 'vm-cus-prod-webapp-${padLeft(i, 3, '0')}'  // vm-cus-prod-webapp-001, 002, 003
  location: location
  // ... rest of configuration
}]

// Or use the naming module with instance parameter
module vm1Naming 'modules/naming/main.bicep' = {
  name: 'vm1-naming'
  params: {
    regionAbbreviation: 'cus'
    environment: 'prod'
    workloadName: 'webapp'
    instance: 1
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vm1Naming.outputs.virtualMachine
  location: location
  // ... rest of configuration
}
```

## Parameters

| Parameter | Type | Required | Allowed Values | Default | Description |
|-----------|------|----------|----------------|---------|-------------|
| `regionAbbreviation` | string | Yes | eus, eus2, wus2, cus | - | Azure region abbreviation |
| `environment` | string | Yes | dev, qa, prod | - | Environment identifier |
| `workloadName` | string | Yes | 2-10 chars | - | Workload or application name |
| `uniqueSuffix` | string | No | max 13 chars | '' | Additional suffix for uniqueness |
| `orgPrefix` | string | No | max 5 chars | '' | Organization abbreviation |
| `instance` | int | No | 1-999 | 1 | Instance number for multi-instance resources |

## Region Abbreviations

| Abbreviation | Full Name |
|--------------|-----------|
| eus | eastus |
| eus2 | eastus2 |
| wus2 | westus2 |
| cus | centralus |

## Naming Patterns

### General Pattern
```
{orgPrefix}-{resourceType}-{regionAbbreviation}-{environment}-{workloadName}-{uniqueSuffix}-{instance}
```

### Resource Groups
```
{orgPrefix}-rg-{fullRegionName}-{environment}-{workloadName}
```
Example: `contoso-rg-centralus-prod-webapp`

### Storage Accounts (no hyphens, lowercase only)
```
{orgPrefix}st{regionAbbr}{env}{workload}{uniqueSuffix}
```
Example: `contososteusprodwebappabcd1234` (max 24 chars)

### Key Vault (max 24 chars)
```
{orgPrefix}-kv-{regionAbbr}-{env}-{workload}-{uniqueSuffix}
```
Example: `contoso-kv-eus-prod-webapp`

### Virtual Machines
- **Linux** (max 64 chars): `{orgPrefix}-vm-{regionAbbr}-{env}-{workload}-{instance}`
- **Windows** (max 15 chars): `{orgPrefix}vm{regionAbbr}{env}{workload}{instance}`

Example: 
- Linux: `contoso-vm-cus-prod-webapp-001`
- Windows: `contososvmcusprodweb1`

## Character Limits Handling

The module automatically enforces Azure's character limits for each resource type:

| Resource Type | Max Length | Notes |
|---------------|------------|-------|
| Storage Account | 24 | Lowercase, no hyphens |
| Key Vault | 24 | Lowercase, alphanumeric and hyphens |
| Windows VM | 15 | Alphanumeric and hyphens |
| Linux VM | 64 | Alphanumeric and hyphens |
| SQL Server | 63 | Lowercase, alphanumeric and hyphens |
| Container Registry | 50 | Alphanumeric only |
| Web App | 60 | Alphanumeric and hyphens |

## Best Practices

1. **Use Unique Suffixes for Globally Unique Resources**
   ```bicep
   uniqueSuffix: uniqueString(resourceGroup().id, subscription().subscriptionId)
   ```

2. **Consistent Region Abbreviations**
   - Always use the same abbreviation mapping across all deployments
   - Document your abbreviation standards

3. **Organization Prefix**
   - Use a short (3-5 char) organization identifier
   - Helps identify resources in multi-tenant scenarios

4. **Instance Numbering**
   - Use for resources that scale horizontally (VMs, NICs, disks)
   - Always use 3-digit padding (001, 002, etc.)

5. **Environment Naming**
   - Stick to standard environments: dev, qa, prod
   - Add additional environments by extending the allowed values

## Integration with Existing Code

To refactor existing code to use the naming module:

### Before
```bicep
param environment string
param workloadName string

var keyVaultName = 'kv-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var webAppName = 'app-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
```

### After
```bicep
module naming 'modules/naming/main.bicep' = {
  name: 'naming-convention'
  params: {
    regionAbbreviation: 'cus'
    environment: environment
    workloadName: workloadName
    uniqueSuffix: uniqueString(resourceGroup().id)
  }
}

var keyVaultName = naming.outputs.keyVault
var webAppName = naming.outputs.webApp
```

## Validation

The module includes built-in validation:
- ✅ Region abbreviation must be in allowed list
- ✅ Environment must be dev/qa/prod
- ✅ Workload name: 2-10 characters
- ✅ Unique suffix: max 13 characters
- ✅ Organization prefix: max 5 characters
- ✅ Instance number: 1-999

## References

- [Azure CAF - Resource Naming](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure CAF - Resource Abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Azure Resource Naming Restrictions](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-22 | Initial release with 50+ resource types |

## Contributing

To add new resource types:
1. Find the official abbreviation in [CAF documentation](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
2. Add variable with naming pattern
3. Add output with description
4. Update this README
5. Test naming matches Azure resource naming restrictions

## License

This module follows the same license as the parent repository.
