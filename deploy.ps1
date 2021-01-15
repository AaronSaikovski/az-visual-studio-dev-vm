##Deploy ARM teplate using powershell

#Login to Azure
Login-AzAccount
    
#Vars
$subscriptionId="<CHANGE_ME>"
$resourceGroupName="<CHANGE_ME>"

#Select Subscription
#Syntax
Select-AzSubscription -SubscriptionId $subscriptionId 

#Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location australiaeast

#Deploy ARM template using powershell
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "azuredeploy.json" -TemplateParameterFile "azuredeploy.parameters.json" -AsJob

#Remove Resource Group
#Syntax
#Remove-AzResourceGroup -Name <Name>
#Actual
Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob