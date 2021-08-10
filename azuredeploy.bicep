@description('VM admin user name')
param vmAdminUserName string

@description('VM admin password. The supplied password must be between 8-12 characters long and must satisfy at least 3 of password complexity requirements from the following: 1) Contains an uppercase character 2) Contains a lowercase character 3) Contains a numeric digit 4) Contains a special character.')
@secure()
param vmAdminPassword string

@description('Which version of Visual Studio you would like to deploy')
param vmVisualStudioVersion string = 'vs-2019-ent-latest-win10-n'

@description('Globally unique naming prefix for per region for the public IP address. For instance, myVMuniqueIP.westus.cloudapp.azure.com. It must conform to the following regular expression: ^[a-z][a-z0-9-]{1,61}[a-z0-9]$.')
param vmIPPublicDnsNamePrefix string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('VM Size')
@allowed([
  'Standard_B2ms'
  'Standard_D2s_v4'
  'Standard_D4s_v4'
  'Standard_E2as_v4'
  'Standard_B4ms'
])
param vmSize string = 'Standard_B2ms'

@description('OS Disk Size')
@allowed([
  '64'
  '128'
  '256'
  '512'
  '1024'
])
param OSdiskSizeGB string = '256'
param virtualMachineExtensionCustomScriptUri string = 'https://raw.githubusercontent.com/AaronSaikovski/chocolatelyinstallers/master/chocolately-install.ps1'

var vmName_var = '${substring(vmVisualStudioVersion, 0, 8)}vm'
var vnet01Prefix = '10.0.0.0/16'
var vnet01Subnet1Name = 'Subnet-1'
var vnetName_var = 'vnet'
var vnet01Subnet1Prefix = '10.0.0.0/24'
var vmImagePublisher = 'MicrosoftVisualStudio'
var vmImageOffer = 'visualstudio2019latest'
var vmSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName_var, vnet01Subnet1Name)
var vmNicName_var = '${vmName_var}-nic'
var vmIP01Name_var = 'VMIP01'
var networkSecurityGroupName_var = '${vnet01Subnet1Name}-nsg'

resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: networkSecurityGroupName_var
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-3389-Inbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnetName 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: vnetName_var
  location: location
  tags: {
    displayName: 'VNet01'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet01Prefix
      ]
    }
    subnets: [
      {
        name: vnet01Subnet1Name
        properties: {
          addressPrefix: vnet01Subnet1Prefix
          networkSecurityGroup: {
            id: networkSecurityGroupName.id
          }
        }
      }
    ]
  }
}

resource vmNicName 'Microsoft.Network/networkInterfaces@2020-07-01' = {
  name: vmNicName_var
  location: location
  tags: {
    displayName: 'VMNic01'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnetRef
          }
          publicIPAddress: {
            id: vmIP01Name.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnetName
  ]
}

resource vmName 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName_var
  location: location
  tags: {
    displayName: 'VM01'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName_var
      adminUsername: vmAdminUserName
      adminPassword: vmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmVisualStudioVersion
        version: 'latest'
      }
      osDisk: {
        caching: 'None'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: OSdiskSizeGB
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNicName.id
        }
      ]
    }
    licenseType: 'Windows_Client'
  }
}

resource vmName_installcustomscript 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  parent: vmName
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        virtualMachineExtensionCustomScriptUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ./chocolately-install.ps1'
    }
  }
}

resource vmIP01Name 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
  name: vmIP01Name_var
  location: location
  tags: {
    displayName: 'VMIP01'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: vmIPPublicDnsNamePrefix
    }
  }
}

output vm_fqdn string = vmIP01Name.properties.dnsSettings.fqdn