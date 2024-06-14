$acrName = "andrewacr"
$token = az acr login --name $acrName --expose-token --output tsv --query accessToken

$acrLoginServer = "$acrName.azurecr.io"
# The username is a required parameter but isn't used for token auth so a fake username is passed.
$username = "00000000-0000-0000-0000-000000000000"

podman machine start

$env:REGISTRY_AUTH_FILE = Join-Path -Path $env:TEMP -ChildPath "podman_auth.json"
$authJson = @{
    auths = @{
        $acrLoginServer = @{
            auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${token}"))
        }
    }
} | ConvertTo-Json

Set-Content -Path $env:REGISTRY_AUTH_FILE -Value $authJson

podman login $acrLoginServer --username $username --password $token
