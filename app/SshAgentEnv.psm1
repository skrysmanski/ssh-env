# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking

function Get-SshAgentEnvFilePath([bool] $OldFile = $false) {
	$localDataPath = Get-SshLocalDataPath
	if (-Not $OldFile) {
		return Join-Path $localDataPath 'ssh-agent-env.json'
	}
	else {
		return Join-Path $localDataPath 'ssh-agent.env'
	}
}

#
# Loads the ssh-agent env variables into the current process, if they exist. Otherwise
# nothing happens.
#
function Import-SshAgentEnv([bool] $Force = $false) {
	if (($env:SSH_AGENT_ENV_LOADED -eq '1') -and (-Not $Force)) {
		# Already loaded and no force reload.
		return
	}

	$envFilePath = Get-SshAgentEnvFilePath
	if (-Not (Test-Path $envFilePath -PathType Leaf)) {
		# Try old file...
		$oldEnvFilePath = Get-SshAgentEnvFilePath -OldFile $true
		if (-Not (Test-Path $oldEnvFilePath -PathType Leaf)) {
			return
		}

		$envFileContents = Get-Content $oldEnvFilePath -Encoding 'utf8'
		$agentEnv = Parse-NativeSshAgentEnvText $envFileContents
		if (-Not $agentEnv) {
			# File is incomplete or otherwise damaged.
			return
		}

		# Save info into new structure and remove old file
		Save-SshAgentEnv $agentEnv
		Remove-Item $oldEnvFilePath | Out-Null
	}
	else {
		$envFileContents = Get-Content $envFilePath -Encoding 'utf8' -Raw

		if ([string]::IsNullOrWhiteSpace($envFileContents)) {
			return
		}

		try {
			$agentEnv = ConvertFrom-Json $envFileContents
		}
		catch {
			# Invalid JSON file.
			return
		}
	}

	# NOTE: The names of the following two env variables are predefined and must NOT BE CHANGED!
	$env:SSH_AUTH_SOCK = $agentEnv.SshAuthSock
	$env:SSH_AGENT_PID = $agentEnv.SshAgentPid

	if ($env:SSH_AUTH_SOCK -and $env:SSH_AGENT_PID) {
		$env:SSH_AGENT_ENV_LOADED = '1'
	}
}

function Parse-NativeSshAgentEnvText($NativeAgentEnv) {
	foreach ($envLine in $NativeAgentEnv) {
		if ($envLine -match '^\s*setenv\s+([^\s]+)\s+([^;]+)\s*;\s*$') {
			if ($Matches[1] -eq 'SSH_AUTH_SOCK') {
				# This is required by ssh to detect the ssh-agent
				$sshAuthSock = $Matches[2]
			}
			elseif ($Matches[1] -eq 'SSH_AGENT_PID') {
				$sshAgentPid = 0
				if (![int]::TryParse($Matches[2], [ref]$sshAgentPid)) {
					$sshAgentPid = $null
				}
			}
		}
	}

	if ($sshAuthSock -and $sshAgentPid) {
		# All necessary information could be found
		return @{
			SshAuthSock = $sshAuthSock
			SshAgentPid = $sshAgentPid
		}
	}
	else {
		return $null
	}
}

function Save-SshAgentEnv($AgentEnvAsObject) {
	$envFilePath = Get-SshAgentEnvFilePath

	$agentEnvAsString = ConvertTo-Json $AgentEnvAsObject
	Write-FileSafe -FileName $envFilePath -Contents $agentEnvAsString
}

function Clear-SshAgentEnv() {
	$env:SSH_AUTH_SOCK = $null
	$env:SSH_AGENT_PID = $null
	$env:SSH_AGENT_ENV_LOADED = $null
}

function Get-SshAgentPid([bool] $checkProcess = $true) {
	Import-SshAgentEnv

	$agentPid = $env:SSH_AGENT_PID
	if (-Not $checkProcess) {
		return $agentPid
	}

	if ($agentPid) {
		if (Test-SshAgentPid $agentPid) {
			return $agentPid
		}
	}

	# Error case: The reported PID is wrong.
	Clear-SshAgentEnv
	return $null
}

function Test-SshAgentPid($agentPid) {
	$agentProcess = Get-Process -Id $agentPid -ErrorAction SilentlyContinue

	if ($agentProcess -and $agentProcess.ProcessName -eq 'ssh-agent') {
		return $true
	}

	return $false
}
