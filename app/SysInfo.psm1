# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"
Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/1Password.psm1"

function Get-OperatingSystemName() {
	if (Test-IsWindows) {
		return 'Windows'
	}
	elseif ($IsMacOs) {
		return 'macOS'
	}
	elseif ($IsLinux) {
		return 'Linux'
	}
	else {
		return 'unsupported'
	}
}

function Get-1PasswordIntegrationStatus() {
	if (-Not (Test-Is1PasswordIntegrationSupported)) {
		return "unsupported operating system"
	}

	if (-Not (Test-Is1PasswordInstalled)) {
		return "1Password not installed"
	}

	if (-Not (Test-Is1PasswordSshAgentEnabled)) {
		return "1Password SSH agent not enabled"
	}

	return "1Password SSH agent enabled"
}

function Write-SysInfo() {
	$osName = Get-OperatingSystemName
	Write-Host "Operating System:       $osName"

	if (Test-IsWindows) {
		if (Test-IsMicrosoftSsh) {
			Write-Host 'Use Microsoft SSH:      yes'
		}
		else {
			Write-Host 'Use Microsoft SSH:      no'
		}
	}

	$1passwordStatus = Get-1PasswordIntegrationStatus
	Write-Host "1Password Intergration: $1passwordStatus"
}
Export-ModuleMember -Function Write-SysInfo
