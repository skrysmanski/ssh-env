# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking

function Get-SshAgentEnvFilePath {
	$localDataPath = Get-SshLocalDataPath
	return Join-Path $localDataPath 'ssh-agent.env'
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
		return
	}

	$envFileContents = Get-Content $envFilePath -Encoding 'utf8'
	foreach ($envLine in $envFileContents) {
		if ($envLine -match '^\s*setenv\s+([^\s]+)\s+([^;]+)\s*;\s*$') {
			if ($Matches[1] -eq 'SSH_AUTH_SOCK') {
				# This is required by ssh to detect the ssh-agent
				# NOTE: The name of this variable is predefined and must NOT BE CHANGED
				$env:SSH_AUTH_SOCK = $Matches[2]
			}
			elseif ($Matches[1] -eq 'SSH_AGENT_PID') {
				# NOTE: The name of this variable is predefined and must NOT BE CHANGED
				$env:SSH_AGENT_PID = $Matches[2]
			}
		}
	}

	if ($env:SSH_AUTH_SOCK -and $env:SSH_AGENT_PID) {
		$env:SSH_AGENT_ENV_LOADED = '1'
	}
}

function Save-SshAgentEnv($AgentEnv) {
	$envFilePath = Get-SshAgentEnvFilePath

	# TODO: We could convert the output to JSON here to decouple the whole process a little bit more from a shell
	Write-FileSafe -FileName $envFilePath -Contents $AgentEnv
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
		$agentProcess = Get-Process -Id $agentPid -ErrorAction SilentlyContinue
		if ($agentProcess -and $agentProcess.ProcessName -eq 'ssh-agent') {
			return $agentPid
		}
	}

	# Error case: The reported PID is wrong.
	Clear-SshAgentEnv
	return $null
}
