# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"
Import-Module "$PSScriptRoot/SshAgentConf.psm1"
Import-Module "$PSScriptRoot/SshAgentEnv.psm1"

Enum SshAgentStatus {
	RunningWithKey = 0
	RunningWithoutKey = 1
	NotRunning = 2
}

#
# Returns the status of the ssh-agent.
#
function Get-SshAgentStatus {
	$sshAgentPid = Get-SshAgentPid

	if (-Not $sshAgentPid) {
		# On macOS it's possible to have "SSH_AUTH_SOCK" but not "SSH_AGENT_PID". This happens because there's always
		# a (global) ssh-agent running. However, we don't want to add keys to this agent but to our own (this is a little
		# bit more secure because the agent is not that easily accessible).
		return [SshAgentStatus]::NotRunning
	}
	else {
		# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
		try {
			& ssh-add -l 2>&1 | Out-Null
			return [SshAgentStatus]$LASTEXITCODE
		}
		catch {
			# Ignore - we get this when no agent is running.
			return [SshAgentStatus]::NotRunning
		}
	}
}

#
# Writes the ssh-agent status to stdout.
#
function Write-SshAgentStatus {
	$agentStatus = Get-SshAgentStatus

	Write-Host -NoNewline 'ssh-agent: '
	switch ($agentStatus) {
		RunningWithKey {
			Write-Host -NoNewline -ForegroundColor Green 'running (keys loaded)'
			$sshAgentPid = Get-SshAgentPid
			Write-Host -ForegroundColor DarkGray " [PID: $sshAgentPid]"
			break
		}

		RunningWithoutKey {
			Write-Host -NoNewline -ForegroundColor Green 'running (no keys loaded)'
			$sshAgentPid = Get-SshAgentPid
			Write-Host -ForegroundColor DarkGray " [PID: $sshAgentPid]"
			break
		}

		NotRunning {
			Write-Host -ForegroundColor Yellow 'not running'
			break
		}

		default {
			Write-Host -ForegroundColor Red "unknown status ($agentStatus)"
			break
		}
	}
}

#
# Starts a new ssh-agent instance and stores its env variables on disk.
#
function Start-SshAgent {
	$sshAgentCommand = Get-Command 'ssh-agent'

	Write-Host -ForegroundColor DarkGray "Starting new ssh-agent instance from: $($sshAgentCommand.Source)"

	# Starts the new agent instance and prints its env variables on stdout
	# -c creates the output in "C-shell commands" which is easier to parse
	# than "Bourne shell commands" (which would be -s and the default most of the time).
	#
	# NOTE: The process being started here will actually start a second ssh-agent process
	#   in the background - and then exit after it has written the info about the second
	#   process to stdout. Thus, we can't use the PID of this command to find the
	#   background process.
	$agentEnvAsString = & $sshAgentCommand.Source -c

	if (-Not $?) {
		throw "'ssh-agent -c' failed."
	}

	if (-Not $agentEnvAsString) {
		throw "'ssh-agent -c' didn't return any configuration"
	}

	$agentEnv = ConvertFrom-NativeSshAgentEnvText $agentEnvAsString
	if (-Not $agentEnv) {
		Write-Error "The process 'ssh-agent' could be started but it didn't provide all the necessary information."
	}

	if (Test-IsWindows -And -Not (Test-SshAgentPid $agentEnv.SshAgentPid)) {
		# Workaround for ssh on Windows that's compiled against Cygwin which then uses different
		# PIDs for the "Linux" and the "Windows" part.
		# See: https://github.com/git-for-windows/git/issues/2274
		try {
			$winPidAsString = & cat.exe "/proc/$($agentEnv.SshAgentPid)/winpid" 2>&1
		}
		catch {
			$winPidAsString = $null
		}

		if (![string]::IsNullOrWhiteSpace($winPidAsString)) {
			$winPid = 0
			if ([int]::TryParse($winPidAsString, [ref]$winPid)) {
				$agentEnv.SshAgentPid = $winPid
			}
		}
	}

	Save-SshAgentEnv $agentEnv

	Import-SshAgentEnv -Force $true

	$effectiveAgentPid = Get-SshAgentPid
	if ($effectiveAgentPid) {
		Write-Host -ForegroundColor DarkGray "ssh-agent now running under PID $effectiveAgentPid"
	}
	else {
		$agentPid = Get-SshAgentPid -CheckProcess $false
		Write-Error "ssh-agent was reported to run under PID $agentPid but we can't find it there."
	}
}

function Stop-SshAgent {
	$agentStatus = Get-SshAgentStatus
	$agentPid = Get-SshAgentPid

	if (($agentStatus -ne [SshAgentStatus]::NotRunning) -And ($agentPid)) {
		Write-Host "Stopping ssh-agent process (pid: $agentPid)"
		Stop-Process -Id $agentPid

		$envFilePath = Get-SshAgentEnvFilePath
		Remove-Item $envFilePath

		Clear-SshAgentEnv

		return $true
	}
	else {
		return $false
	}
}

function Add-SshKeyToRunningAgent([String] $SshPrivateKeyPath, [int] $KeyTimeToLive) {
	if ($KeyTimeToLive -ne 0) {
		# Add key for a limited time only
		& ssh-add -t $KeyTimeToLive "$SshPrivateKeyPath"
	}
	else {
		# Add key indefinitely (until the agent is stopped)
		& ssh-add "$SshPrivateKeyPath"
	}

	if (-Not $?) {
		throw 'ssh-add failed'
	}
}

function Assert-SshAgentState([String] $SshPrivateKeyPath) {
	if (-Not (Test-Path $SshPrivateKeyPath)) {
		Write-Error "Private SSH key doesn't exist at: $SshPrivateKeyPath`nDid you run: ./ssh-env datadir init/clone ?"
	}

	$agentConf = Get-SshAgentConfig -CreateIfNotExists

	if ($agentConf.useSshAgent) {
		$agentStatus = Get-SshAgentStatus
		if ($agentStatus -eq 'NotRunning') {
			Start-SshAgent
			$addKey = $true
		}
		elseif ($agentStatus -eq 'RunningWithoutKey') {
			$addKey = $true
		}
		else {
			# Already has the key
			$addKey = $false
		}

		if ($addKey) {
			Write-Host -ForegroundColor Green -NoNewline $SshPrivateKeyPath
			Write-Host " not yet loaded. Loading it..."
			Add-SshKeyToRunningAgent -SshPrivateKeyPath $SshPrivateKeyPath -KeyTimeToLive $agentConf.keyTimeToLive
			Write-Host
		}
	}
	else {
		# Don't use agent.
		Stop-SshAgent | Out-Null
	}
}
