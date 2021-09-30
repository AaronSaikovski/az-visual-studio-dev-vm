##Deploy Bicepo using powershell

#Login to Azure
Login-AzAccount
    
#Vars
$subscriptionId     = "<CHANGE_ME>"
$resourceGroupName  = "<CHANGE_ME>"
$location           = "australiaeast"

#Get Tags from Json file
$tags = Get-Content 'tags.json' | ConvertFrom-Json -AsHashtable

#Select Subscription
#Syntax
Select-AzSubscription -SubscriptionId $subscriptionId 

#Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location -Tag $tags

#Deploy bicep template using powershell
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "template.bicep"  -AsJob

#Remove Resource Group
#Syntax
#Remove-AzResourceGroup -Name <Name>
#Actual
Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob