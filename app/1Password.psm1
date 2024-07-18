#
# Module for 1Password integration
#
# See: https://developer.1password.com/docs/ssh/get-started
#

# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"

function Test-Is1PasswordIntegrationSupported() {
	return Test-IsWindows -or $IsMacOs
}
Export-ModuleMember -Function Test-Is1PasswordIntegrationSupported

function Test-Is1PasswordInstalled() {
	if (-Not (Test-Is1PasswordIntegrationSupported)) {
		return $false
	}

	if (Get-Process '1password' -ErrorAction SilentlyContinue)
	{
		return $true
	}
	else {
		return $false
	}
}
Export-ModuleMember -Function Test-Is1PasswordInstalled

function Get-1PasswordSettingsFilePath() {
	if (Test-IsWindows) {
		return "$([Environment]::GetFolderPath('LocalApplicationData'))\1Password\settings\settings.json"
	}
	elseif ($IsMacOs) {
		throw 'macOS support for 1password detection is not yet implemented'
	}
	else {
		throw 'The 1Password intergration is not supported for the current operating system.'
	}
}

function Test-Is1PasswordSshAgentEnabled() {
	$settingsFile = Get-1PasswordSettingsFilePath

	if (-Not (Test-Path $settingsFile -PathType Leaf)) {
		return $false
	}

	$1passwordSettings = Get-Content $settingsFile | ConvertFrom-Json
	if ($1passwordSettings.'sshAgent.enabled' -eq $true) {
		return $true
	}
	else {
		return $false
	}
}
Export-ModuleMember -Function Test-Is1PasswordSshAgentEnabled
