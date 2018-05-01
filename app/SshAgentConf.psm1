# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/Utils.psm1" -DisableNameChecking

function Get-SshAgentConfigFilePath {
	$localDataPath = Get-SshLocalDataPath
	return Join-Path $localDataPath 'ssh-agent.config'
}

function Configure-SshAgent {
	$DEFAULT_KEY_TTL = 10

	$useSshAgent = Prompt-YesNo 'Do you want to use ssh-agent?' -DefaultValue $true

	if ($useSshAgent -eq 'y') {
		$useSshAgent = $true

		$keyTimeToLive = Prompt-Integer "How long should the private key be kept in memory (seconds; 0 = forever)" -DefaultValue $DEFAULT_KEY_TTL
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
	Write-FileUtf8NoBom -Path $configFilePath -Contents $configFileContents

	Write-Host
	Write-Host -NoNewline 'SSH agent config file created at: '
	Write-Host -ForegroundColor Green $configFilePath
	Write-Host
}

function Get-SshAgentConfig {
	$configFilePath = Get-SshAgentConfigFilePath

	if (-Not (Test-Path $configFilePath)) {
		return $null
	}

	return Get-Content $configFilePath -Encoding 'utf8' | ConvertFrom-Json
}
