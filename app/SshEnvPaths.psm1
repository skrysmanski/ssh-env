# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1" -DisableNameChecking

function Set-SshEnvPaths([string] $SshDataPath = 'ssh-data', [string] $LocalDataPath = '.local') {
	Sync-CurrentWorkingDirectory

	# NOTE: We can't use "Resolve-Path" here as the directory may not yet exist.
	$script:sshDataPath = [Io.Path]::GetFullPath($SshDataPath)
	$script:localDataPath = [Io.Path]::GetFullPath($LocalDataPath)
}

function Get-SshEnvPath([string] $Path, [string] $PathName, [bool] $CreateIfNotExists) {
	if (-Not $Path) {
		# NOTE: If you get here but can't explain why, then maybe some script imported
		#  this module using "-Force" thereby clearing all "$script:xxx" variables.
		Write-Error "$PathName is not configured"
	}

	if ($CreateIfNotExists -And (-Not (Test-Path $Path -PathType Container))) {
		# IMPORTANT: We must use '| Out-Null' here or the directory will be the
		#   first result value of this method - which leads to seemingly strange
		#   behavior in conjunction with 'Test-Path'
		New-Item $Path -ItemType Directory | Out-Null
	}

	return $Path
}

function Get-SshDataPath([bool] $CreateIfNotExists = $true) {
	return Get-SshEnvPath $script:sshDataPath -PathName 'sshDataPath' -CreateIfNotExists $CreateIfNotExists
}

function Get-SshLocalDataPath([bool] $CreateIfNotExists = $true) {
	return Get-SshEnvPath $script:localDataPath -PathName 'localDataPath' -CreateIfNotExists $CreateIfNotExists
}
