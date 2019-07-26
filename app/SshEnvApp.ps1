# Stop on every error
$script:ErrorActionPreference = 'Stop'

& $PSScriptRoot/Unload-Modules.ps1

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshAgent.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshKey.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshEnvAppAux.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/Installation.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshDataDir.psm1" -DisableNameChecking

if ($args.Length -eq 0) {
	Write-Help 'No command specified'
	exit 0
}

function Invoke-SshWithAgent {
	$sshConfigPath = Ensure-SshConfigIsUpToDate

	$privateKeyPath = Get-SshPrivateKeyPath
	Ensure-SshAgentState -SshPrivateKeyPath $privateKeyPath

	$sshCommand = Get-Command 'ssh'
	Write-Host -ForegroundColor DarkGray "Using ssh from: $($sshCommand.Source)"

	& $sshCommand.Source -F $sshConfigPath @args
}

function Execute-SshEnvApp {
	# Make sure everything is installed properly.
	Assert-SoftwareInstallation

	Assert-FolderIsEncrypted
	Ensure-CorrectSshKeyPermissions

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

		'datadir' {
			switch ($args[1]) {
				'clone' {
					Clone-DataDir
					break
				}

				'init' {
					New-DataDir
					break
				}

				'' {
					Write-HelpAndExit "Missing 'datadir' command"
					break
				}

				default {
					Write-HelpAndExit "Unknown 'datadir' command: $($args[1])"
					break
				}
			}
			break
		}


		'keys' {
			switch ($args[1]) {
				'create' {
					New-SshKey
					break
				}

				'install' {
					$target = $args[2]
					if (-Not $target) {
						Write-HelpAndExit 'Missing target server where to install the key'
					}
					Install-SshKey $target
					break
				}

				'check' {
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
}

try {
	Execute-SshEnvApp @args
}
catch [Microsoft.PowerShell.Commands.WriteErrorException] {
	# Print error messages (without stacktrace)
	Write-Host -ForegroundColor Red $_.Exception.Message
	exit 1
}
catch {
	# Print proper exception message (including stack trace)
	# NOTE: We can't create a catch block for "RuntimeException" as every exception
	#   seems to be interpreted as RuntimeException.
	if ($_.Exception.GetType() -eq [System.Management.Automation.RuntimeException]) {
		Write-Host -ForegroundColor Red $_.Exception.Message
	}
	else {
		Write-Host -ForegroundColor Red "$($_.Exception.GetType().Name): $($_.Exception.Message)"
	}
	Write-Host -ForegroundColor Red $_.ScriptStackTrace
	exit 1
}
