
$envName = "poc"
$appName = "testapp"
$locName = "cus"
$repoName = "ptc23"


$createDt = (Get-Date).ToString("yyyy-MM-dd")
$appOwner = "mbenko"
$createBy = "$env:USERNAME"


# Create SPN for workload

$devGroup = "IMADEMO-$appName-$envName" # -DEV"
$rgName = "$envName-$locName-$appName-rg"
$spnName = "imademo-$appName-$envName"

az account set --subscription fy23-devdad-sandbox # POC

$subID=$(az account show --query id -o tsv)
$tenantID=$(az account show --query tenantId -o tsv)


## AZURE RG CREATION
# Check that Security group exists
az ad group list -o table | select-string $devGroup


# Create the RG
az group create -n $rgName -l centralus --tags "Environment=$envName" "CreatedBy=$createBy" "CreateDt=$createDt" "Owner=$appOwner" "App=$appName" "Repo=$repoName" "Location=$locName"
az group show -n $rgName -o table
az group list -o table | select-string $rgName
az role assignment create --assignee $(az ad group show --group "$devGroup-DEV" --query id --output tsv) --role "contributor" --scope /subscriptions/$subID/resourceGroups/$rgName 

## CREATE SPN
# Create if it doesn't exist
$spnSecret = az ad sp create-for-rbac -n $spnName --sdk-auth --scopes /subscriptions/$subID/resourceGroups/$rgName --role owner

# to refresh credentials...
$spnId = az ad sp list --display-name $spnName --query '[0].appId' --output tsv
$spnSecret =  az ad sp credential reset --id $spnId --query "{subscriptionId: '$subId', clientId: appId, clientSecret: password, tenantId: tenant }" -o json | Out-String
$spnSecretObj = $spnSecret | ConvertFrom-Json
$encodedSecret = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($spnSecretObj.ToString()))

# Update/Set the secret in GitHub and Test that it works
gh secret set $secretName --body $encodedSecret -o mbenko -v selected --repos $repoName
gh workflow run az-login -R mbenko/ptc -f secret-name=$secretName


## STOP HERE

## GITHUB STUFF

# Add contributors to repo (Permssions: pull, triage, push, maintain, admin)  Admin includes access to secrets
gh api --method=PUT "repos/mbenko/ptc23/collaborators/bnkdevdad" -permission=pull

# Remove contributors from repo
gh api --method=DELETE "repos/mbenko/ptc23/collaborators/bnkdevdad"


# Copy workflow from template to target repo
git clone https://github.com/mbenko/ptc23 ../tmp-app-inflate
xcopy ..\tmp-app-inflate\.github\*.* .\.github\*.* /s/d/c
del ..\tmp-app-inflate /s/q
rmdir ..\tmp-app-inflate /s/q


# Take inventory
az ad sp list --display-name $spnName
az ad sp list --all --query "sort_by([].{AppDisplayName:displayName, AppId:appId, CreateDate:createdDateTime}, &CreateDate)" -o table
az ad sp list -o table

# to clean up
az group delete -g $rgName
az ad sp delete --display-name $spnName
