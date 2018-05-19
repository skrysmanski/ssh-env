# Stop on every error
$script:ErrorActionPreference = 'Stop'

$script:SshEnvBasePath = Resolve-Path "$PSScriptRoot/.."

function Get-SshEnvPath([string] $RelativePath, [bool] $CreateIfNotExists) {
	$Path = Join-Path $script:SshEnvBasePath $RelativePath

	if ($CreateIfNotExists -And (-Not (Test-Path $Path -PathType Container))) {
		# IMPORTANT: We must use '| Out-Null' here or the directory will be the
		#   first result value of this method - which leads to seemingly strange
		#   behavior in conjunction with 'Test-Path'
		New-Item $Path -ItemType Directory | Out-Null
	}

	return $Path
}

function Get-SshDataPath([bool] $CreateIfNotExists = $true) {
	return Get-SshEnvPath 'ssh-data' -CreateIfNotExists $CreateIfNotExists
}

function Get-SshLocalDataPath([bool] $CreateIfNotExists = $true) {
	return Get-SshEnvPath '.local' -CreateIfNotExists $CreateIfNotExists
}
