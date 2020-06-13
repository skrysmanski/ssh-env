# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1"
Import-Module "$PSScriptRoot/Utils.psm1"

function Get-SshAgentConfigFilePath {
	$localDataPath = Get-SshLocalDataPath
	return Join-Path $localDataPath 'ssh-agent.settings.json'
}

function Initialize-SshAgentConfig {
	$DEFAULT_KEY_TTL = 10

	$useSshAgent = Read-YesNoPrompt 'Do you want to use ssh-agent?' -DefaultValue $true

	if ($useSshAgent -eq 'y') {
		$useSshAgent = $true

		$keyTimeToLive = Read-IntegerPrompt "How long should the private key be kept in memory (seconds; 0 = forever)" -DefaultValue $DEFAULT_KEY_TTL
	}
	else {
		$useSshAgent = $false
		# Write default even if ssh-agent isn't used.
		$keyTimeToLive = $DEFAULT_KEY_TTL
	}

	$data = @{
		useSshAgent = $useSshAgent
		keyTimeToLive = $keyTimeToLive
	}

	$configFileContents = $data | ConvertTo-Json

	$configFilePath = Get-SshAgentConfigFilePath
	Write-FileUtf8NoBom -FilePath $configFilePath -Contents $configFileContents

	Write-Host
	Write-Host -NoNewline 'SSH agent config file created at: '
	Write-Host -ForegroundColor Green $configFilePath
	Write-Host
}
Export-ModuleMember -Function Initialize-SshAgentConfig

function Get-SshAgentConfig([switch] $CreateIfNotExists) {
	$configFilePath = Get-SshAgentConfigFilePath

	if (-Not (Test-Path $configFilePath)) {
		if ($CreateIfNotExists) {
			Write-Host
			Write-Host -ForegroundColor Green -NoNewline $configFilePath
			Write-Host " doesn't exist. Creating it."
			Write-Host
			Initialize-SshAgentConfig
		}
		else {
			return $null
		}
	}

	return Get-Content $configFilePath -Encoding 'utf8' -Raw | ConvertFrom-Json
}
Export-ModuleMember -Function Get-SshAgentConfig
