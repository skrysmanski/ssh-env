# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/SshEnvPaths.psm1"
Import-Module "$PSScriptRoot/Utils.psm1"
Import-Module "$PSScriptRoot/1Password.psm1"

function Get-SshAgentConfigFilePath {
	$localDataPath = Get-SshLocalDataPath
	return Join-Path $localDataPath 'ssh-agent.settings.json'
}

function Initialize-SshAgentConfig {
	$DEFAULT_KEY_TTL = 900

	$sshEnvCommands = Get-SshEnvCommands

	$useSshAgent = Read-YesNoPrompt 'Do you want to use ssh-agent?' -DefaultValue $true
	$use1PasswordSshAgent = $false

	if ($useSshAgent -eq 'y') {
		$useSshAgent = $true

		if (Test-Is1PasswordInstalled) {
			$use1PasswordSshAgent = Read-YesNoPrompt "1Password is installed. Do you want to use 1Password's SSH agent?" -DefaultValue $true
			$keyTimeToLive = 0
		}

		if (-Not $use1PasswordSshAgent) {
			if (Test-IsMicrosoftSsh) {
				# Microsoft SSH-agent implementation doesn't support time-to-live for SSH keys.
				# See: https://github.com/PowerShell/Win32-OpenSSH/issues/1510
				# See: https://github.com/PowerShell/Win32-OpenSSH/issues/1056
				$confirm = Read-YesNoPrompt "Microsoft's ssh-agent implementation stores private keys indefinitely (even through a reboot). Do you still want to use ssh-agent?"
				if ($confirm) {
					$keyTimeToLive = 0
				}
				else {
					Write-Error 'Aborting'
				}
			}
			else {
				$keyTimeToLive = Read-IntegerPrompt "How long should the private key be kept in memory (seconds; 0 = forever)" -DefaultValue $DEFAULT_KEY_TTL
			}
		}
	}
	else {
		$useSshAgent = $false
		# Write default even if ssh-agent isn't used.
		$keyTimeToLive = $DEFAULT_KEY_TTL
	}

	$data = @{
		UseSshAgent = $useSshAgent
		Use1PasswordSshAgent = $use1PasswordSshAgent
		KeyTimeToLive = $keyTimeToLive
		ConfiguredSsh = $sshEnvCommands.Ssh
	}

	$configFileContents = $data | ConvertTo-Json

	$configFilePath = Get-SshAgentConfigFilePath
	Write-FileUtf8NoBom -FilePath $configFilePath -Contents $configFileContents

	Write-Host
	Write-Host -NoNewline 'SSH agent config file created at: '
	Write-Host -ForegroundColor Green $configFilePath
	Write-Host

	return $data
}
Export-ModuleMember -Function Initialize-SshAgentConfig

#
# Returns the desired configuration of the SSH agent (e.g. whether to use, what time-to-live for keys, ...).
#
# If no configuration exists yet, returns $null by default.
#
# However, if "-CreateIfNotExists" is specified, the user is prompted for the configuration in this case.
#
function Get-SshAgentConfig([switch] $CreateIfNotExists) {
	$configFilePath = Get-SshAgentConfigFilePath

	if (-Not (Test-Path $configFilePath)) {
		if ($CreateIfNotExists) {
			Write-Host
			Write-Host -ForegroundColor Green -NoNewline $configFilePath
			Write-Host " doesn't exist. Creating it."
			Write-Host
			return Initialize-SshAgentConfig
		}
		else {
			return $null
		}
	}

	$sshEnvCommands = Get-SshEnvCommands

	$config = Get-Content $configFilePath -Encoding 'utf8' -Raw | ConvertFrom-Json

	if ($config.ConfiguredSsh -ne $sshEnvCommands.Ssh) {
		if ($CreateIfNotExists) {
			Write-Host
			Write-Host -ForegroundColor Green -NoNewline $configFilePath
			Write-Host " is configured for a different SSH implementation. Recreating it."
			Write-Host
			return Initialize-SshAgentConfig
		}
		else {
			return $null
		}
	}

	return $config
}
Export-ModuleMember -Function Get-SshAgentConfig

#
# Returns whether the 1Password SSH agent is used.
#
function Test-Use1PasswordSshAgent() {
	$agentConf = Get-SshAgentConfig

	if ($agentConf -And $agentConf.UseSshAgent -And $agentConf.Use1PasswordSshAgent) {
		return $true
	}
	else {
		return $false
	}
}
Export-ModuleMember -Function Test-Use1PasswordSshAgent
