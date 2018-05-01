# Stop on every error
$script:ErrorActionPreference = 'Stop'

& $PSScriptRoot/Unload-Modules.ps1

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshAgent.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshKey.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshEnvAppAux.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/Ssh.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/Installation.psm1" -DisableNameChecking

if ($args.Length -eq 0) {
	Write-Help 'No command specified'
	exit 0
}

# Make sure everything is installed properly.
Assert-SoftwareInstallation

Set-SshEnvPaths

Assert-FolderIsEncrypted
Ensure-CorrectSshKeyPermissions

function Test-IsSshDataPathAvailable {
	$sshDataPath = Get-SshDataPath -CreateIfNotExists $false

	if (-Not (Test-Path $sshDataPath)) {
		return $false
	}

	if (Test-IsFolderEmpty $sshDataPath) {
		# Data path exists but is empty.
		return $false
	}

	return $true
}

function Assert-SshDataIsAvailable {
	if (-Not (Test-IsSshDataPathAvailable)) {
		Write-Host
		Write-Host -ForegroundColor Cyan 'No SSH data available. Starting setup process...'
		Write-Host

		Import-Module "$PSScriptRoot/bootstrapping/Bootstrapping.psm1" -DisableNameChecking
		Install-SshDataDir

		$sshPrivateKeyPath = Get-SshPrivateKeyPath
		if (-Not (Test-Path $sshPrivateKeyPath)) {
			# SSH private key not yet there. User chose to import it manually. We can't continue until he does.
			exit 0
		}
	}
}

function Invoke-SshWithAgent {
	Assert-SshDataIsAvailable

	$privateKeyPath = Get-SshPrivateKeyPath
	Ensure-SshAgentState -SshPrivateKeyPath $privateKeyPath
	Invoke-Ssh @args
}

switch -Regex ($args[0]) {
	'agent' {
		switch ($args[1]) {
			'status' {
				Write-SshAgentStatus
				break
			}

			'config' {
				Configure-SshAgent
				break
			}

			'stop' {
				$stopped = Stop-SshAgent
				if ($stopped) {
					Write-Host 'ssh-agent: stopped'
				}
				else {
					Write-Host 'ssh-agent: not running'
				}
				break
			}

			'' {
				Write-HelpAndExit "Missing 'agent' command"
				break
			}

			default {
				Write-HelpAndExit "Unknown 'agent' command: $($args[1])"
				break
			}
		}
		break
	}


	'keys' {
		switch ($args[1]) {
			'create' {
				# Special case: If the ssh data directory is not yet created, don't call New-SshKey as this will
				# be called from the bootstrapping process anyways.
				if (Test-IsSshDataPathAvailable) {
					New-SshKey
				}
				else {
					# This will also create the key.
					Assert-SshDataIsAvailable
				}
				break
			}

			'install' {
				Assert-SshDataIsAvailable

				$target = $args[2]
				if (-Not $target) {
					Write-HelpAndExit 'Missing target server where to install the key'
				}
				Install-SshKey $target
				break
			}

			'check' {
				Assert-SshDataIsAvailable

				Check-SshKeyEncryption
				break
			}

			'' {
				Write-HelpAndExit "Missing 'keys' command"
				break
			}

			default {
				Write-HelpAndExit "Unknown 'keys' command: $($args[1])"
				break
			}
		}
		break
	}

	'version|--version|-v' {
		$version = Get-EnvVersion
		Write-Host "ssh-env version $version"

		& ssh -V

		$sshCommand = Get-Command 'ssh'
		$sshBinariesPath = Split-Path $sshCommand.Source -Parent
		Write-Host -ForegroundColor DarkGray "Using SSH binaries from: $sshBinariesPath"
		break
	}

	'-h|--help|help' {
		Write-Help
		break
	}

	'ssh' {
		$sshArgs = $args[1..$args.Length] # Remove first item ('ssh')
		Invoke-SshWithAgent @sshArgs
		break
	}

	default {
		Invoke-SshWithAgent @args
		break
	}
}
