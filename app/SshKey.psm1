# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Installation.psm1"
Import-Module "$PSScriptRoot/Utils.psm1"
Import-Module "$PSScriptRoot/SshConfig.psm1"
Import-Module "$PSScriptRoot/SshAgentConf.psm1"

function New-SshKeyPair {
	if (Test-Use1PasswordSshAgent) {
		Write-Host -ForegroundColor Yellow "SSH keys can't be created this way if 1Password's SSH agent is used."
		Write-Host -ForegroundColor Yellow "Use 1Password to create a new SSH key."
		return
	}

	$sshEnvCommands = Get-SshEnvCommands

	# Request the user's name from the user. Note this is actually just
	# a comment and is copied over to the target system when running
	# "install-key". There it is then used to make it easier to differentiate
	# the various authorized keys (as stored in "~/.ssh/authorized_keys").
	$userName = [Environment]::UserName
	$keyPairComment = Read-TextPrompt "Who does this SSH key belong to?" -DefaultValue $userName

	$sshPrivateKeyPath = Get-SshPrivateKeyPath -CreateDirIfNotExists $true

	# Parameters:
	# -o : store private key with bcrypt encryption (which makes brute-force decrypting hard)
	# -t : create RSA key
	# -b : use 4096 bits
	# -C : add comment to generated public key
	# -f : output file
	# See also: http://www.manpagez.com/man/1/ssh-keygen/
	& $sshEnvCommands.SshKeyGen -o -t rsa -b 4096 -C "$keyPairComment" -f "$sshPrivateKeyPath"
	if (-Not $?) {
		Write-Error 'ssh-keygen failed'
	}

	Assert-CorrectSshKeyPermissions
}
Export-ModuleMember -Function New-SshKeyPair

function Install-SshKey([String] $SshTarget) {
	$sshEnvCommands = Get-SshEnvCommands

	$sshConfigPath = Assert-SshConfigIsUpToDate

	$sshPublicKeyPath = Get-SshPublicKeyPath

	if (-Not (Test-Path $sshPublicKeyPath -PathType Leaf)) {
		if (Test-Use1PasswordSshAgent) {
			Write-Host -ForegroundColor Yellow "No public key file exists at: $sshPublicKeyPath"
			Write-Host
			Write-Host "Unfortunately, the public key of your SSH key can't be automatically extracted from 1Password."
			Write-Host -ForegroundColor Cyan "So, please copy the public(!) key of your SSH key and paste it here."
			Write-Host

			$publicKey = Read-TextPrompt "Public Key"
			Write-Host

			if (-Not ($publicKey.StartsWith('ssh-'))) {

				Write-Error "The entered key doesn't seem to be a valid SSH public key! Did you accidentally paste your private key?"
			}

			# Request the user's name from the user. Note this is actually just
			# a comment and is copied over to the target system when running
			# "install-key". There it is then used to make it easier to differentiate
			# the various authorized keys (as stored in "~/.ssh/authorized_keys").
			$userName = [Environment]::UserName
			$keyPairComment = Read-TextPrompt "Who does this SSH key belong to?" -DefaultValue $userName
			Write-Host

			Write-FileUtf8NoBom $sshPublicKeyPath "$publicKey $keyPairComment`n"

			Write-Host -ForegroundColor Green "Public key saved to: $sshPublicKeyPath"
			Write-Host
		}
		else {
			Write-Error "No public key file exists at: $sshPublicKeyPath`nYou can create your SSH key pair with 'ssh-env key create'."
		}
	}

	$publicKey = Get-Content $sshPublicKeyPath -Encoding 'utf8'

	# Use ':' to separate port in this case.
	if ($SshTarget.Contains(':')) {
		$parts = $SshTarget.Split(':')
		if ($parts.Length -ne 2) {
			Write-Error "The target name '$SshTarget' is invalid."
		}

		$SshTarget = $parts[0]
		$port = $parts[1]
	}
	else {
		$port = 22
	}

	$originalInputEncoding = [Console]::InputEncoding
	try {
		# NOTE: We need to change the input encoding here or PowerShell will add an UTF-8 BOM to the
		#   public key - making it unusable.
		#   See: https://stackoverflow.com/q/60124466/614177
		[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

		# Does basically the same thing as "ssh-copy-id". The problem with "ssh-copy-id" is that you can't
		# specify the SSH config file and thus it won't work here.
		#
		# The 'PreferredAuthentications' option (see 'man ssh_config') makes sure the user isn't asked
		# for the password to his/her SSH private key (which may be confusing to the user at this point).
		#
		# For some guidance on this command see:
		# * http://askubuntu.com/a/6186/62255
		# * https://github.com/openssh/openssh-portable/blob/master/contrib/ssh-copy-id
		$publicKey | & $sshEnvCommands.Ssh -F $sshConfigPath -o 'PreferredAuthentications keyboard-interactive,password' -p $port $SshTarget "exec sh -c 'cd ; umask 077 ; mkdir -p .ssh && cat >> .ssh/authorized_keys || exit 1'"
	}
	finally {
		[Console]::InputEncoding = $originalInputEncoding
	}
}
Export-ModuleMember -Function Install-SshKey

function Write-SshKeyEncryptionStateToHost {
	if (Test-Use1PasswordSshAgent) {
		Write-Host -ForegroundColor Yellow "Private SSH keys can't be checked this way if 1Password's SSH agent is used."
		Write-Host -ForegroundColor Yellow "Use 1Password to check the SSH key pair for problems."
		return
	}

	$sshEnvCommands = Get-SshEnvCommands

	$sshPrivateKeyPath = Get-SshPrivateKeyPath

	if (-Not (Test-Path $sshPrivateKeyPath)) {
		Write-Host -ForegroundColor Red "ERROR: SSH key pair doesn't exist."
		return
	}

	Write-Host -NoNewline 'Encryption: '
	try {
		& $sshEnvCommands.SshKeyGen -p -P [String]::Empty -N [String]::Empty -f $sshPrivateKeyPath 2>&1 | Out-Null
	}
	catch {
		# Ignore errors - they're expected if the key is encrypted
	}
	if ($?) {
		Write-Host -ForegroundColor Red 'not encrypted'
	}
	else {
		# NOTE: It's not a security problem to read the private key file here
		#   (in plain text) because we know it's encrypted.
		$privateKey = Get-Content $sshPrivateKeyPath -Encoding 'utf8'

		if ($privateKey.Contains('Proc-Type: 4,ENCRYPTED')) {
			Write-Host -ForegroundColor Yellow 'encrypted, weak'
		}
		else {
			Write-Host -ForegroundColor Green 'encrypted, strong'
		}
	}
}
Export-ModuleMember -Function Write-SshKeyEncryptionStateToHost

function Assert-CorrectSshKeyPermissions {
	if (Test-IsPosix) {
		$sshPrivateKeyPath = Get-SshPrivateKeyPath
		if (Test-Path $sshPrivateKeyPath) {
			& chmod 0600 $sshPrivateKeyPath
			if (-Not $?) {
				Write-Error "chmod on private key failed."
			}
		}
	}
}
Export-ModuleMember -Function Assert-CorrectSshKeyPermissions
