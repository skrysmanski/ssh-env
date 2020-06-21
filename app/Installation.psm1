# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"

function Get-SshEnvCommands() {
	if ($script:SshEnvCommands) {
		return $script:SshEnvCommands
	}

	$checkedLocations = @()

	$sshCommand = Get-Command 'ssh' -ErrorAction SilentlyContinue
	if ($sshCommand) {
		$sshEnvCommands = GetSshEnvCommandsIfExist $sshCommand.Source
		if ($sshEnvCommands) {
			$script:SshEnvCommands = $sshEnvCommands
			return $sshEnvCommands
		}

		$checkedLocations += $sshCommand.Source
	}

	if (Test-IsWindows) {
		$sshCommands = GetSshExecutablesFromGitForWindows
		foreach ($sshCommand in $sshCommands) {
			$sshEnvCommands = GetSshEnvCommandsIfExist $sshCommand
			if ($sshEnvCommands) {
				$script:SshEnvCommands = $sshEnvCommands
				return $sshEnvCommands
			}
			$checkedLocations += $sshCommand
		}
	}

	if ($checkedLocations.Count -eq 0) {
		Write-Error 'Could not locate "ssh" executable.'
	}
	else {
		Write-Error "Could not locate full SSH installation (but found the ssh executable in: $([string]::Join(', ', $checkedLocations)))."
	}
}
Export-ModuleMember -Function Get-SshEnvCommands

function Test-IsMicrosoftSsh() {
	$sshEnvCommands = Get-SshEnvCommands
	return $sshEnvCommands.IsMicrosoftSsh
}
Export-ModuleMember -Function Test-IsMicrosoftSsh

function Get-GitCommand() {
	$command = Get-Command 'git' -ErrorAction SilentlyContinue
	if (-Not $command) {
		Write-Error 'Could not locate "git" executable. Is Git installed?'
	}

	return $command.Source
}
Export-ModuleMember -Function Get-GitCommand

function GetSshExecutablesFromGitForWindows() {
	$allCommands = @()

	# Check default installation folder of "Git for Windows"
	$sshCommand = GetBinaryPathIfExists "$env:ProgramFiles\Git\usr\bin" 'ssh'
	if ($sshCommand) {
		$allCommands += $sshCommand
	}

	$gitCommand = Get-Command 'git' -ErrorAction SilentlyContinue
	if ($gitCommand) {
		# Test different "Git for Windows" installation folder;
		# e.g.: D:\Programs\Git\cmd\git.exe
		$sshCommand = GetBinaryPathIfExists "$($gitCommand.Source)\..\..\usr\bin" 'ssh'
		if ($sshCommand) {
			$allCommands += $sshCommand
		}
	}

	return $allCommands
}

function GetSshEnvCommandsIfExist([string] $SshCommand) {
	$binDir = [IO.Path]::GetDirectoryName($SshCommand)

	$sshAgentCommand = GetBinaryPathIfExists $BinDir 'ssh-agent'
	if (!$sshAgentCommand) {
		return $false
	}

	$sshAddCommand = GetBinaryPathIfExists $BinDir 'ssh-add'
	if (!$sshAddCommand) {
		return $false
	}

	$sshKeyGenCommand = GetBinaryPathIfExists $BinDir 'ssh-keygen'
	if (!$sshKeyGenCommand) {
		return $false
	}

	if (Test-IsWindows) {
		if ($SshCommand.StartsWith($env:windir, [System.StringComparison]::OrdinalIgnoreCase)) {
			# Seems we're using Microsoft's SSH port.
			$isMicrosoftSsh = $true
		}
	}

	if (!$isMicrosoftSsh) {
		$catCommand = GetBinaryPathIfExists $BinDir 'cat'
		if (!$catCommand) {
			return $false
		}
	}

	return @{
		Ssh            = $SshCommand
		SshAgent       = $sshAgentCommand
		SshAdd         = $sshAddCommand
		SshKeyGen      = $sshKeyGenCommand
		Cat            = $catCommand
		IsMicrosoftSsh = $isMicrosoftSsh
	}
}

function GetBinaryPathIfExists([string] $BinDir, [string] $BinaryName) {
	$binaryPath = Join-Path $BinDir $BinaryName

	if (Test-IsWindows) {
		$binaryPath += '.exe'
	}

	if (-Not (Test-Path $binaryPath -PathType Leaf)) {
		return $false
	}

	return [IO.Path]::GetFullPath($binaryPath)
}
