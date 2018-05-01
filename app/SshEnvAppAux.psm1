# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1" -DisableNameChecking

function Get-EnvVersion {
	return Get-Content "$PSScriptRoot/VERSION.txt" -Encoding 'utf8'
}

function Write-Help([String] $error = $null) {
	if ($error) {
		Write-Host -ForegroundColor Red "ERROR: $error"
		Write-Host
	}

	Get-Content "$PSScriptRoot/help.txt" -Encoding 'utf8' | Write-Host
}

function Write-HelpAndExit([String] $error = $null) {
	Write-Help $error

	if ($error) {
		exit 1
	}
	else {
		exit 0
	}
}

function Assert-FolderIsEncrypted {
	$appPath = Split-Path $PSScriptRoot -Parent
	if ((Test-IsFolderEncrypted $appPath) -eq $false) {
		Write-Host -ForegroundColor Yellow "WARNING: This folder is not encrypted. You should encrypt it for"
		Write-Host -ForegroundColor Yellow "  improved security. For more information, go to:"
		Write-Host -ForegroundColor Yellow "  https://msdn.microsoft.com/en-us/library/dd163562.aspx"
		Write-Host
	}
}
