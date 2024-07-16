# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/SshEnvPaths.psm1"
Import-Module "$PSScriptRoot/SshEnvConf.psm1"
Import-Module "$PSScriptRoot/SshAgentConf.psm1"
Import-Module "$PSScriptRoot/SshAgent.psm1"
Import-Module "$PSScriptRoot/SshAgentEnv.psm1"

function Get-GlobalSshConfigPath([bool] $CreateDirIfNotExists) {
	$baseDir = [IO.Path]::Combine($HOME, '.ssh')

	if ($CreateDirIfNotExists -and (-Not (Test-Path $baseDir -PathType Container))) {
		New-Item $baseDir -ItemType Directory | Out-Null
	}

	return [IO.Path]::Combine($baseDir, 'config')
}
Export-ModuleMember -Function Get-GlobalSshConfigPath

function Get-SshConfigPath([bool] $RuntimeConfig = $true, [bool] $CreateDirIfNotExists = $false) {
	if ($runtimeConfig) {
		$localDataPath = Get-SshLocalDataPath -CreateIfNotExists $CreateDirIfNotExists
		$localRuntimeConfigPath = Join-Path $localDataPath 'ssh.generated.conf'

		$sshEnvConf = Get-SshEnvConfig
		if ($sshEnvConf.GloballyInstalled) {
			# If the ssh config is globally installed, remove the local version to avoid
			# confusion (and bugs).
			if (Test-Path $localRuntimeConfigPath) {
				Remove-Item $localRuntimeConfigPath
			}

			# NOTE: If globally installed, we switch over to the "global" config file. Unfortunaly,
			#   we can't use a symlink for this because creating symlinks on Windows requires admin
			#   rights. -.-
			return Get-GlobalSshConfigPath -CreateDirIfNotExists $CreateDirIfNotExists
		}
		else {
			return $localRuntimeConfigPath
		}
	}
	else {
		$sshDataPath = Get-SshDataPath -CreateIfNotExists $CreateDirIfNotExists
		return Join-Path $sshDataPath 'config'
	}
}
Export-ModuleMember -Function Get-SshConfigPath

function New-DefaultSshConfig {
	$sshConfigPath = Get-SshConfigPath -RuntimeConfig $false -CreateDirIfNotExists $true
	if (Test-Path $sshConfigPath) {
		throw 'ssh config file already exists'
	}

	Copy-Item "$PSScriptRoot/templates/default-ssh-config.conf" $sshConfigPath
}
Export-ModuleMember -Function New-DefaultSshConfig

function Get-SshPrivateKeyPath([bool] $CreateDirIfNotExists = $false) {
	$sshDataPath = Get-SshDataPath -CreateIfNotExists $CreateDirIfNotExists
	return Join-Path $sshDataPath 'id_rsa'
}
Export-ModuleMember -Function Get-SshPrivateKeyPath

function Get-SshPublicKeyPath {
	$privateKeyPath = Get-SshPrivateKeyPath
	return $privateKeyPath + '.pub'
}
Export-ModuleMember -Function Get-SshPublicKeyPath

function Get-RuntimeSshConfig {
	$sshConfigPath = Get-SshConfigPath -RuntimeConfig $false
	if (Test-Path $sshConfigPath) {
		$sshConfig = Get-Content $sshConfigPath -Encoding 'utf8' -Raw
	}
	else {
		$sshConfig = ''
	}

	$sshAgentConf = Get-SshAgentConfig -CreateIfNotExists
	if ($sshAgentConf -and $sshAgentConf.useSshAgent) {
		$sshAgentStatus = Get-SshAgentStatus

		if ($sshAgentStatus -eq 'NotRunning') {
			Start-SshAgent
		}

		if (Test-IsMicrosoftSsh) {
			$identityAgentDeclaration = "# not required by Microsoft's SSH implementation"
		}
		else {
			$sshAgentSockFilePath = Get-SshAgentSockFilePath

			if (-Not $sshAgentSockFilePath) {
				throw 'Could not determine ssh-agent auth sock path.'
			}

			$identityAgentDeclaration = "IdentityAgent $sshAgentSockFilePath"
		}
	}
	else {
		$identityAgentDeclaration = 'IdentityAgent none'
	}

	$sshEnvPath = Get-SshEnvPath -CreateIfNotExists $false
	$sshDataPath = Get-SshDataPath
	$privateKeyPath = Get-SshPrivateKeyPath
	$knownHostsPath = [IO.Path]::Combine($sshDataPath, 'known_hosts')

	return @"
# IMPORTANT: This file is AUTO-GENERATED. Do NOT edit manually!!!

# Using ssh-env from: $sshEnvPath

# ssh (secure shell) configuration file
# See: https://man.openbsd.org/ssh_config
#

# IMPORTANT: The next two options are specified here (rather than via the commandline)
#   to make multi-hop SSH hosts (i.e. ProxyCommand) easier.
# Location of the "known_hosts" file.
UserKnownHostsFile $knownHostsPath

# Location of the private key file.
IdentityFile $privateKeyPath

# By specifying this, the ssh-agent of ssh-env can be used by other processes
# by just referencing this config file.
$identityAgentDeclaration

# Prevents ssh from adding the SSH key to the ssh-agent.
# NOTE: We set this to 'no' because there's no way to configure the
#   key's lifetime via the SSH config. If we enabled this setting,
#   all keys would be added with "infinite" lifetime to the ssh-agent -
#   thereby ignoring the configured lifetime (in ssh-agent-config.json).
AddKeysToAgent no

###################################

$sshConfig
"@
}

function Assert-SshConfigIsUpToDate {
	$runtimeSshConfig = Get-RuntimeSshConfig

	$runtimeSshConfigPath = Get-SshConfigPath -RuntimeConfig $true -CreateDirIfNotExists $true
	if (Test-Path $runtimeSshConfigPath) {
		$runtimeConfigFromDisk = Get-Content $runtimeSshConfigPath -Encoding 'utf8' -Raw
		if ($runtimeConfigFromDisk -ceq $runtimeSshConfig) {
			# Already up-to-date
			return $runtimeSshConfigPath
		}
	}

	# NOTE: Since this file contains the path to the ssh-agent auth sock, it needs
	#   better protection.
	Write-FileUtf8NoBomWithSecurePermissions -FilePath $runtimeSshConfigPath -Contents $runtimeSshConfig
	return $runtimeSshConfigPath
}
Export-ModuleMember -Function Assert-SshConfigIsUpToDate
