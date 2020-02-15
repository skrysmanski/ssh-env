# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking

function Get-SshEnvConfigFilePath() {
	$localDataPath = Get-SshLocalDataPath
	return Join-Path $localDataPath 'ssh-env.settings.json'
}

function Get-SshEnvConfig() {
	$configFilePath = Get-SshEnvConfigFilePath

	if (-Not (Test-Path $configFilePath)) {
		return @{
			GloballyInstalled = $false
		}
	}

	return Get-Content $configFilePath -Encoding 'utf8' -Raw | ConvertFrom-Json
}