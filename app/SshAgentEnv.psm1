# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1"

function Get-SshAgentEnvFilePath([bool] $OldFile = $false) {
	if (Test-IsMicrosoftSsh) {
		throw "Not supported with Microsoft' SSH implementation."
	}

	$localDataPath = Get-SshLocalDataPath
	if (-Not $OldFile) {
		return Join-Path $localDataPath 'ssh-agent-env.json'
	}
	else {
		return Join-Path $localDataPath 'ssh-agent.env'
	}
}
Export-ModuleMember -Function Get-SshAgentEnvFilePath

#
# Loads the ssh-agent env variables into the current process, if they exist. Otherwise
# nothing happens.
#
function Import-SshAgentEnv([bool] $Force = $false) {
	if (Test-IsMicrosoftSsh) {
		throw "Not supported with Microsoft' SSH implementation."
	}

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
		$agentEnv = ConvertFrom-NativeSshAgentEnvText $envFileContents
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
Export-ModuleMember -Function Import-SshAgentEnv

function ConvertFrom-NativeSshAgentEnvText($NativeAgentEnv) {
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
Export-ModuleMember -Function ConvertFrom-NativeSshAgentEnvText

function Save-SshAgentEnv($AgentEnvAsObject) {
	if (Test-IsMicrosoftSsh) {
		throw "Not supported with Microsoft' SSH implementation."
	}

	$envFilePath = Get-SshAgentEnvFilePath

	$agentEnvAsString = ConvertTo-Json $AgentEnvAsObject
	Write-FileUtf8NoBomWithSecurePermissions -FilePath $envFilePath -Contents $agentEnvAsString
}
Export-ModuleMember -Function Save-SshAgentEnv

function Clear-SshAgentEnv() {
	$env:SSH_AUTH_SOCK = $null
	$env:SSH_AGENT_PID = $null
	$env:SSH_AGENT_ENV_LOADED = $null
}
Export-ModuleMember -Function Clear-SshAgentEnv

function Get-SshAgentPid([bool] $checkProcess = $true) {
	if (Test-IsMicrosoftSsh) {
		# There's no good way of getting the PID of a service. So we don't support this.
		throw "Not supported with Microsoft' SSH implementation."
	}

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
Export-ModuleMember -Function Get-SshAgentPid

function Test-SshAgentPid($agentPid) {
	$agentProcess = Get-Process -Id $agentPid -ErrorAction SilentlyContinue

	if ($agentProcess -and $agentProcess.ProcessName -eq 'ssh-agent') {
		return $true
	}

	return $false
}
Export-ModuleMember -Function Test-SshAgentPid

function Get-SshAgentSockFilePath() {
	if (Test-IsMicrosoftSsh) {
		throw "ssh-agent sock files are not used with Microsoft's SSH implementation."
	}

	$agentPid = Get-SshAgentPid

	if (-Not $agentPid) {
		# Agent is not running
		return $null
	}

	return $env:SSH_AUTH_SOCK
}
Export-ModuleMember -Function Get-SshAgentSockFilePath
