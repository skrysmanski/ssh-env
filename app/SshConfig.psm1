# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking

function Get-SshConfigPath([bool] $RuntimeConfig = $true) {
	if ($runtimeConfig) {
		$localDataPath = Get-SshLocalDataPath
		return Join-Path $localDataPath 'ssh.generated.conf'
	}
	else {
		$sshDataPath = Get-SshDataPath
		return Join-Path $sshDataPath 'config'
	}
}

function Get-SshPrivateKeyPath {
	$sshDataPath = Get-SshDataPath
	return Join-Path $sshDataPath 'id_rsa'
}

function Get-SshPublicKeyPath {
	$privateKeyPath = Get-SshPrivateKeyPath
	return $privateKeyPath + '.pub'
}

function Create-RuntimeSshConfig {
	$sshConfigPath = Get-SshConfigPath -RuntimeConfig $false
	if (Test-Path $sshConfigPath) {
		$sshConfig = Get-Content $sshConfigPath -Encoding 'utf8' -Raw
	}
	else {
		$sshConfig = ''
	}

	$sshDataPath = Get-SshDataPath
	$privateKeyPath = Get-SshPrivateKeyPath

	return @"
# ssh (secure shell) configuration file
# See: https://linux.die.net/man/5/ssh_config
#
# NOTE: This file is autogenerated. Do not edit manually.

# IMPORTANT: The next two options are specified here (rather than via the commandline)
#   to make multi-hop SSH hosts (i.e. ProxyCommand) easier.
# Location of the "known_hosts" file.
UserKnownHostsFile $sshDataPath/known_hosts
# Location of the private key file.
IdentityFile $privateKeyPath

$sshConfig
"@
}

function Ensure-SshConfigIsUpToDate {
	$runtimeSshConfig = Create-RuntimeSshConfig

	$runtimeSshConfigPath = Get-SshConfigPath -RuntimeConfig $true
	if (Test-Path $runtimeSshConfigPath) {
		$runtimeConfigFromDisk = Get-Content $runtimeSshConfigPath -Encoding 'utf8' -Raw
		if ($runtimeConfigFromDisk -ceq $runtimeSshConfig)
		{
			# Already up-to-date
			return $runtimeSshConfigPath
		}
	}

	Write-FileUtf8NoBom -Path $runtimeSshConfigPath -Contents $runtimeSshConfig
	return $runtimeSshConfigPath
}
