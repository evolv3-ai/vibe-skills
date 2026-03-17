#Requires -Version 5.1
<#
.SYNOPSIS
    Render Secret File - Retrieve JSON blob from Infisical, write to file
.DESCRIPTION
    Fetches a base64-encoded credential from Infisical and writes it
    to a local file with proper permissions.
.PARAMETER Uri
    Infisical URI (infisical://project/env/folder/key)
.PARAMETER OutputPath
    Path to write the decoded file
.EXAMPLE
    .\Render-SecretFile.ps1 "infisical://admin-operator/prod/files/gcloud/ADC_KEY" -OutputPath .\creds.json
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [string]$Uri,

    [Parameter(Mandatory)]
    [Alias('Output', 'o')]
    [string]$OutputPath
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolve the secret
$encoded = & "$ScriptDir\Resolve-SecretRef.ps1" $Uri 2>$null
if (-not $encoded) {
    Write-Error "Could not resolve secret from $Uri"
    exit 1
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    $null = New-Item -ItemType Directory -Path $outputDir -Force
}

# Decode and write
$decoded = [System.Convert]::FromBase64String($encoded)
[System.IO.File]::WriteAllBytes($OutputPath, $decoded)

Write-Host "Rendered: $OutputPath"
