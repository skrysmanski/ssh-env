# Stop on every error
$script:ErrorActionPreference = 'Stop'

& $PSScriptRoot/Unload-Modules.ps1

Import-Module "$PSScriptRoot/SshEnvPaths.psm1"
Import-Module "$PSScriptRoot/SshEnvConf.psm1"
Import-Module "$PSScriptRoot/SshAgent.psm1"
Import-Module "$PSScriptRoot/SshKey.psm1"
Import-Module "$PSScriptRoot/SshEnvAppAux.psm1"
Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/SshDataDir.psm1"
Import-Module "$PSScriptRoot/SshConfig.psm1"

if ($args.Length -eq 0) {
	Write-Help 'No command specified'
	exit 0
}

function Invoke-SshWithAgent {
	$sshConfigPath = Assert-SshConfigIsUpToDate

	$privateKeyPath = Get-SshPrivateKeyPath
	Assert-SshAgentState -SshPrivateKeyPath $privateKeyPath

	$sshCommand = Get-Command 'ssh'
	Write-Host -ForegroundColor DarkGray "Using ssh from: $($sshCommand.Source)"

	& $sshCommand.Source -F $sshConfigPath @args
}

function Invoke-SshEnvApp {
	# Make sure everything is installed properly.
	Assert-SoftwareInstallation

	Assert-AppDirectoriesAreEncrypted
	Assert-CorrectSshKeyPermissions

	switch -Regex ($args[0]) {
		'agent' {
			switch ($args[1]) {
				'status' {
					Write-SshAgentStatus
					break
				}

				'config' {
					Initialize-SshAgentConfig
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
					Initialize-DataDirViaGitClone
					break
				}

				'init' {
					Initialize-DataDirFromScratch
					break
				}

				'status' {
					$dataDirExists = Test-SshDataDirExists
					Write-Host -NoNewline 'DataDir exists:                '

					if (-Not $dataDirExists) {
						Write-Host -ForegroundColor Red 'no'
						break
					}

					Write-Host -ForegroundColor Green 'yes'

					$sshEnvConfig = Get-SshEnvConfig
					Write-Host -NoNewline 'Is DataDir globally installed: '
					if ($sshEnvConfig.GloballyInstalled) {
						Write-Host -ForegroundColor Cyan 'yes'
					}
					else {
						Write-Host -ForegroundColor Cyan 'no'
					}

					$sshRuntimeConfigPath = Get-SshConfigPath -RuntimeConfig $true
					Write-Host -ForegroundColor DarkGray " -> Runtime SSH config path:   $sshRuntimeConfigPath"

					break
				}

				'global-install' {
					Install-DataDirGlobally
					break
				}

				'global-uninstall' {
					Uninstall-DataDirGlobally
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
					Write-SshKeyEncryptionStateToHost
					break
				}

				'load' {
					$agentConf = Get-SshAgentConfig -CreateIfNotExists
					if ($agentConf.useSshAgent) {
						# Make sure the generated ssh_config is up-to-date so that it can be
						# used by external processes.
						Assert-SshConfigIsUpToDate | Out-Null

						$privateKeyPath = Get-SshPrivateKeyPath
						Assert-SshAgentState -SshPrivateKeyPath $privateKeyPath
					}
					else {
						Write-Error 'Use of ssh-agent is disabled by configuration.'
					}
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
	Invoke-SshEnvApp @args
}
catch {
	function LogError([string] $exception) {
		Write-Host -ForegroundColor Red $exception
	}

	# Type of $_: System.Management.Automation.ErrorRecord

	# NOTE: According to https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/windows-powershell-error-records
	#   we should always use '$_.ErrorDetails.Message' instead of '$_.Exception.Message' for displaying the message.
	#   In fact, there are cases where '$_.ErrorDetails.Message' actually contains more/better information than '$_.Exception.Message'.
	if ($_.ErrorDetails -And $_.ErrorDetails.Message) {
		$unhandledExceptionMessage = $_.ErrorDetails.Message
	}
	elseif ($_.Exception -And $_.Exception.Message) {
		$unhandledExceptionMessage = $_.Exception.Message
	}
	else {
		$unhandledExceptionMessage = 'Could not determine error message from ErrorRecord'
	}

	# IMPORTANT: We compare type names(!) here - not actual types. This is important because - for example -
	#   the type 'Microsoft.PowerShell.Commands.WriteErrorException' is not always available (most likely
	#   when Write-Error has never been called).
	if ($_.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.WriteErrorException') {
		# Print error messages (without stacktrace)
		LogError $unhandledExceptionMessage
	}
	else {
		# Print proper exception message (including stack trace)
		# NOTE: We can't create a catch block for "RuntimeException" as every exception
		#   seems to be interpreted as RuntimeException.
		if ($_.Exception.GetType().FullName -eq 'System.Management.Automation.RuntimeException') {
			LogError "$unhandledExceptionMessage$([Environment]::NewLine)$($_.ScriptStackTrace)"
		}
		else {
			LogError "$($_.Exception.GetType().Name): $unhandledExceptionMessage$([Environment]::NewLine)$($_.ScriptStackTrace)"
		}
	}

	exit 1
}
