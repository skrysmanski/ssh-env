# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"

function Get-EnvVersion {
	return Get-Content "$PSScriptRoot/VERSION.txt" -Encoding 'utf8'
}

function Write-Help([String] $errorMessage = $null) {
	if ($errorMessage) {
		Write-Host -ForegroundColor Red "ERROR: $errorMessage"
		Write-Host
	}

	Get-Content "$PSScriptRoot/help.txt" -Encoding 'utf8' | Write-Host
}

function Write-HelpAndExit([String] $errorMessage = $null) {
	Write-Help $errorMessage

	if ($errorMessage) {
		exit 1
	}
	else {
		exit 0
	}
}

function Assert-DirectoryIsEncrypted($Path) {
	if (-Not (Test-Path $Path)) {
		return
	}

	if ((Test-IsFolderEncrypted $Path) -eq $false) {
		Write-Host -ForegroundColor Yellow "WARNING: The directory '$Path' is not encrypted."
		Write-Host -ForegroundColor Yellow "  You should encrypt it for improved security. For more information, go to:"
		Write-Host -ForegroundColor Yellow "  https://msdn.microsoft.com/en-us/library/dd163562.aspx"
		Write-Host
	}
}

function Assert-AppDirectoriesAreEncrypted {
	$appPath = Split-Path $PSScriptRoot -Parent
	Assert-DirectoryIsEncrypted $appPath

	$globalSshDir = [IO.Path]::Combine($HOME, '.ssh')
	Assert-DirectoryIsEncrypted $globalSshDir
}
