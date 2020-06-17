# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1"

function Get-GitCommand() {
	$command = Get-Command 'git' -ErrorAction SilentlyContinue
	if (-Not $command) {
		Write-Error 'Could not locate "git" executable. Is Git installed?'
	}

	return $command.Source
}
Export-ModuleMember -Function Get-GitCommand

function Assert-SoftwareInstallation {
	$sshCommand = Get-Command 'ssh' -ErrorAction SilentlyContinue
	if ((-Not $sshCommand) -And (Test-IsWindows)) {
		$sshBinariesPath = Get-SshBinariesPathOnWindows
		if ($sshBinariesPath) {
			$env:Path += ";$sshBinariesPath"
			$sshCommand = Get-Command 'ssh' -ErrorAction SilentlyContinue
		}
	}
	if (-Not $sshCommand) {
		Write-Error 'ssh is not installed or not on the PATH variable.'
	}

	if (Test-IsWindows) {
		if ($sshCommand.Source.StartsWith($env:windir, [System.StringComparison]::OrdinalIgnoreCase)) {
			# Seems we're using Microsoft's SSH port which is (at the moment) not compatible
			# because it lacks features we're using.
			if ($sshCommand.Version -le '0.0.18.0') {
				Write-Error "You're using Microsoft's SSH port in a version that is known NOT to work."
			}
			else {
				Write-Host -ForegroundColor Yellow "You're using Microsoft's SSH port which may not work."
			}
		}
	}

	$requiredBinaries = Get-RequiredSshBinaries

	foreach ($binaryName in $requiredBinaries) {
		if ($binaryName -eq 'ssh') {
			# We've already tested this one.
			continue
		}

		$command = Get-Command $binaryName -ErrorAction SilentlyContinue
		if (-Not $command) {
			Write-Error "Could not find required program: $binaryName."
		}
	}
}
Export-ModuleMember -Function Assert-SoftwareInstallation

#
# Returns the SSH programs used by ssh-env (as a list).
#
function Get-RequiredSshBinaries {
	return @(
		'ssh',
		'ssh-agent',
		'ssh-add',
		'ssh-keygen'
	)
}

function Get-SshBinariesPathOnWindows {
	# Check default installation folder of "Git for Windows"
	if (Test-SshBinariesExist "$env:ProgramFiles\Git\usr\bin") {
		return "$env:ProgramFiles\Git\usr\bin"
	}

	$gitCommand = Get-Command 'git' -ErrorAction SilentlyContinue
	if ($gitCommand) {
		# Test different "Git for Windows" installation folder;
		# e.g.: D:\Programs\Git\cmd\git.exe
		$suspectedPath = "$($gitCommand.Source)\..\..\usr\bin"
		if (Test-SshBinariesExist $suspectedPath) {
			return Resolve-Path $suspectedPath
		}
	}

	return $null
}

#
# Checks whether the specified path contains an SSH installation (or to
# be more specific: all SSH programs required by ssh-env).
#
function Test-SshBinariesExist([string] $suspectedPath) {
	if (-Not (Test-Path $suspectedPath -PathType Container)) {
		return $false
	}

	$requiredBinaries = Get-RequiredSshBinaries
	foreach ($binaryName in $requiredBinaries) {
		$binaryPath = Join-Path $suspectedPath $binaryName
		if (Test-IsWindows) {
			$binaryPath += '.exe'
		}

		if (-Not (Test-Path $binaryPath -PathType Leaf)) {
			return $false
		}
	}

	return $true
}
