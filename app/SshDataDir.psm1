# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/SshEnvPaths.psm1"
Import-Module "$PSScriptRoot/Utils.psm1"
Import-Module "$PSScriptRoot/SshKey.psm1"
Import-Module "$PSScriptRoot/SshConfig.psm1"

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
Export-ModuleMember -Function Test-SshDataDirExists

function Assert-SshDataDirDoesntExist {
	if (Test-SshDataDirExists) {
		Write-Error 'The data directory already exists.'
	}
}

function Initialize-DataDirViaGitClone {
	Assert-SshDataDirDoesntExist

	$gitCommand = Get-GitCommand

	$gitUrl = Read-TextPrompt 'URL to SSH data Git repository' -AllowEmpty $false

	$sshDataPath = Get-SshDataPath -CreateIfNotExists $true
	& $gitCommand clone $gitUrl $sshDataPath
	if (-Not $?) {
		Write-Error "Cloning '$gitUrl' failed"
	}

	Assert-CorrectSshKeyPermissions

	Write-Host
	Write-Host -NoNewline 'Cloning SSH data repository: '
	Write-Host -ForegroundColor Green 'success'
	Write-Host
}
Export-ModuleMember -Function Initialize-DataDirViaGitClone

function Initialize-DataDirFromScratch {
	Assert-SshDataDirDoesntExist

	$hasSshKey = Read-YesNoPrompt 'Do you have an SSH key pair (in case of doubt: no)?'
	if (-Not $hasSshKey) {
		Write-Host
		New-SshKey
		Write-Host
	}

	$sshDataPath = Get-SshDataPath -CreateIfNotExists $true

	# Create default config file
	New-DefaultSshConfig

	# Create empty known_hosts file with some helpful comments.
	Copy-Item "$PSScriptRoot/templates/known_hosts" "$sshDataPath/known_hosts"

	$createGitRepo = Read-YesNoPrompt 'Do you want to version the SSH data with Git?' -DefaultValue $true
	if ($createGitRepo) {
		$gitCommand = Get-GitCommand

		try {
			Push-Location $sshDataPath

			& $gitCommand init .
			if (-Not $?) {
				throw 'git init failed'
			}

			# Disable Git's auto eol conversions for the data dir. Not sure
			# how well ssh takes Windows line endings.
			Copy-Item "$PSScriptRoot/templates/git-attributes.txt" "./.gitattributes"

			& $gitCommand add * .gitattributes
			if (-Not $?) {
				throw 'git add failed'
			}

			& $gitCommand commit -m 'SSH data repository created'
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
Export-ModuleMember -Function Initialize-DataDirFromScratch

# Makes the data dir available directly to "ssh" (i.e. without using ssh-env).
function Install-DataDirGlobally() {
	$globalConfigPath = Get-GlobalSshConfigPath -CreateDirIfNotExists $false
	$response = Read-YesNoPrompt "This will overwrite the file '$globalConfigPath' with an auto-generated one. Do you want to continue?"
	if (-Not $response) {
		return
	}

	Set-SshEnvConfig -GloballyInstalled $true

	Assert-SshConfigIsUpToDate | Out-Null
}
Export-ModuleMember -Function Install-DataDirGlobally

function Uninstall-DataDirGlobally() {
	Set-SshEnvConfig -GloballyInstalled $false

	Assert-SshConfigIsUpToDate | Out-Null

	$globalConfigPath = Get-GlobalSshConfigPath -CreateDirIfNotExists $false

	if (Test-Path $globalConfigPath -PathType Leaf) {
		$response = Read-YesNoPrompt "The auto-generated file '$globalConfigPath' can be deleted. Do you want to delete it?"
		if ($response) {
			Remove-Item $globalConfigPath
		}
	}
}
Export-ModuleMember -Function Uninstall-DataDirGlobally
