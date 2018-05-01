# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../SshConfig.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/../SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/../SshKey.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/../Utils.psm1" -DisableNameChecking

function Install-SshDataDir {
	$sshDataPath = Get-SshDataPath
	Write-Host -ForegroundColor DarkGray "Storing SSH data in: $sshDataPath"
	Write-Host

	$hasDataRepo = Prompt-YesNo 'Do you have a Git repository with your SSH data?'
	Write-Host
	if ($hasDataRepo) {
		Get-SshDataRepo
	}
	else {
		New-SshDataRepo
	}
}

function Get-SshDataRepo {
	$sshDataPath = Get-SshDataPath

	$gitUrl = Prompt-Text 'URL to SSH data Git repository' -AllowEmpty $false

	& git clone $gitUrl $sshDataPath
	if (-Not $?) {
		Write-Error "Cloning '$gitUrl' failed"
	}

	Write-Host
	Write-Host -NoNewline 'Cloning SSH data repository: '
	Write-Host -ForegroundColor Green 'sucess'
	Write-Host
}

function New-SshDataRepo {
	$sshDataPath = Get-SshDataPath

	$hasSshKey = Prompt-YesNo 'Do you have an SSH key pair (in case of doubt: no)?'
	if (-Not $hasSshKey) {
		Write-Host
		New-SshKey
		Write-Host
	}

	# Create default config file
	Copy-Item "$PSScriptRoot/ssh-config-template.txt" "$sshDataPath/config"

	$createGitRepo = Prompt-YesNo 'Do you want to version the SSH data with Git?' -DefaultValue $true
	if ($createGitRepo) {
		# Create empty known_hosts file so that it can be added to Git.
		New-Item "$sshDataPath/known_hosts" -ItemType File | Out-Null

		try {
			Push-Location $sshDataPath

			& git init .
			if (-Not $?) {
				Write-Error 'git init failed'
			}

			& git add *
			if (-Not $?) {
				Write-Error 'git add failed'
			}

			& git commit -m 'SSH data repository created'
			if (-Not $?) {
				Write-Error 'git commit failed'
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
