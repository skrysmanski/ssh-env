# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/Utils.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshKey.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshConfig.psm1" -DisableNameChecking

#
# Checks whether the SSH data dir exists and is not empty. If this function returns
# $false, a new data dir can be created or cloned.
#
function Test-SshDataDirExists {
	$sshDataPath = Get-SshDataPath

	if (-Not (Test-Path $sshDataPath)) {
		return $false
	}

	if (Test-IsFolderEmpty $sshDataPath) {
		# Data path exists but is empty.
		return $false
	}

	return $true
}

function Assert-SshDataDirDoesntExist {
	if (Test-SshDataDirExists) {
		Write-Error 'The data directory already exists.'
	}
}

function Initialize-DataDirViaGitClone {
	Assert-SshDataDirDoesntExist

	$gitUrl = Prompt-Text 'URL to SSH data Git repository' -AllowEmpty $false

	$sshDataPath = Get-SshDataPath -CreateIfNotExists $true
	& git clone $gitUrl $sshDataPath
	if (-Not $?) {
		Write-Error "Cloning '$gitUrl' failed"
	}

	Ensure-CorrectSshKeyPermissions

	Write-Host
	Write-Host -NoNewline 'Cloning SSH data repository: '
	Write-Host -ForegroundColor Green 'sucess'
	Write-Host
}

function Initialize-DataDirFromScratch {
	Assert-SshDataDirDoesntExist

	$hasSshKey = Prompt-YesNo 'Do you have an SSH key pair (in case of doubt: no)?'
	if (-Not $hasSshKey) {
		Write-Host
		New-SshKey
		Write-Host
	}

	$sshDataPath = Get-SshDataPath -CreateIfNotExists $true

	# Create default config file
	New-DefaultSshConfig

	# Create empty known_hosts file so that it can be added to Git (or whatever vcs the user wants to use).
	New-Item "$sshDataPath/known_hosts" -ItemType File | Out-Null

	$createGitRepo = Prompt-YesNo 'Do you want to version the SSH data with Git?' -DefaultValue $true
	if ($createGitRepo) {
		try {
			Push-Location $sshDataPath

			& git init .
			if (-Not $?) {
				throw 'git init failed'
			}

			# Disable Git's auto eol conversions for the data dir. Not sure
			# how well ssh takes Windows line endings.
			Copy-Item "$PSScriptRoot/git-attributes.txt" "./.gitattributes"

			& git add * .gitattributes
			if (-Not $?) {
				throw 'git add failed'
			}

			& git commit -m 'SSH data repository created'
			if (-Not $?) {
				throw 'git commit failed'
			}
		}
		finally {
			Pop-Location
		}
	}

	Write-Host
	Write-Host -NoNewline 'Creating SSH data folder: '
	Write-Host -ForegroundColor Green 'sucess'
	Write-Host

	if ($hasSshKey) {
		$sshPrivateKeyPath = Get-SshPrivateKeyPath
		$sshPublicKeyPath = Get-SshPublicKeyPath

		Write-Host 'You need to manually copy your SSH key pair to:'
		Write-Host
		Write-Host " *  Private key: $sshPrivateKeyPath"
		Write-Host " *  Public key:  $sshPublicKeyPath"
	}
}

# Makes the data dir available directly to "ssh" (i.e. without using ssh-env).
function Install-DataDirGlobally() {
	$globalConfigPath = Get-GlobalSshConfigPath -CreateDirIfNotExists $false
	$response = Prompt-YesNo "This will overwrite the file '$globalConfigPath' with an auto-generated one. Do you want to continue?"
	if (-Not $response) {
		return
	}

	Set-SshEnvConfig -GloballyInstalled $true

	Assert-SshConfigIsUpToDate | Out-Null
}

function Uninstall-DataDirGlobally() {
	Set-SshEnvConfig -GloballyInstalled $false

	Assert-SshConfigIsUpToDate | Out-Null

	$globalConfigPath = Get-GlobalSshConfigPath -CreateDirIfNotExists $false

	if (Test-Path $globalConfigPath -PathType Leaf) {
		$response = Prompt-YesNo "The auto-generated file '$globalConfigPath' can be deleted. Do you want to delete it?"
		if ($response) {
			Remove-Item $globalConfigPath
		}
	}
}
