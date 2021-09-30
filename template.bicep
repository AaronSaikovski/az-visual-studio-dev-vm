/*
* Description:      Deploys a Windows 10 Virtual machine with Visual studio 2019 and runs a post deployment chocolately script to install other bits - takes 30mins or so to provision.
* Author:           asaikovski@outlook.com
* Version:          1.0
*
* Input Parameters:
*                   'vmAdminUserName'         - VM Admin username
*                   'vmAdminPassword'         - VM Admin password
*                   'vmIPPublicDnsNamePrefix' - Public DNS Name - in format - <DNSNAME>.<REGION>.cloudapp.azure.com
*/
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
/*@allowed([
  'Standard_B2ms'
  'Standard_D2s_v4'
  'Standard_D4s_v4'
  'Standard_E2as_v4'
  'Standard_B4ms'
])*/
param vmSize string = 'Standard_D2s_v4'

@description('OS Disk Size')
@allowed([
  64
  128
  256
  512
  1024
])
param OSdiskSizeGB int = 256

@description('OS Disk SKU')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
param storageAccountDiskSku string = 'StandardSSD_LRS'

@description('OS Disk Caching')
@allowed([
  'None'
  'ReadOnly'
  'ReadWrite'
])
param storageAccountDiskCaching string = 'None'

param virtualMachineExtensionCustomScriptUri string = 'https://raw.githubusercontent.com/AaronSaikovski/chocolatelyinstallers/master/chocolately-install.ps1'

var vmName_var = '${substring(vmVisualStudioVersion, 0, 8)}vm'
var vnet01Prefix = '10.0.0.0/16'
var vnet01Subnet1Name = '${vmName_var}-sn'
var vnetName_var = '${vmName_var}-vnet'
var vnet01Subnet1Prefix = '10.0.0.0/24'
var vmImagePublisher = 'MicrosoftVisualStudio'
var vmImageOffer = 'visualstudio2019latest'
var vmSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName_var, vnet01Subnet1Name)
var vmNicName_var = '${vmName_var}-nic'
var vmIP01Name_var = '${vmName_var}-pip01'
var networkSecurityGroupName_var = '${vnet01Subnet1Name}-nsg'


//Dynamically tags subnets from JSON file
var tags = json(loadTextContent('./tags.json'))

//NSG
resource networkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: networkSecurityGroupName_var
  location: location
  tags:tags
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

//Vnet
resource vnetName 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName_var
  location: location
  tags:tags
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

//VM NIC
resource vmNicName 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: vmNicName_var
  location: location
  tags:tags
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

//Virtual Machine
resource vmName 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: vmName_var
  location: location
  tags:tags
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
        caching: storageAccountDiskCaching
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountDiskSku
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

//custom script extension install
resource vmName_installcustomscript 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  parent: vmName
  name: 'installcustomscript'
  location: location
  tags:tags
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

//public IP
resource vmIP01Name 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: vmIP01Name_var
  location: location
  tags:tags
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: vmIPPublicDnsNamePrefix
    }
  }
}

output vm_fqdn string = vmIP01Name.properties.dnsSettings.fqdn
