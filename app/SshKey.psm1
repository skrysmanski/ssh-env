# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/Utils.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshConfig.psm1" -DisableNameChecking

function New-SshKey {
	# Request the user's name from the user. Note this is actually just
	# a comment and is copied over to the target system when running
	# "install-key". There it is then used to make it easier to differentiate
	# the various authorized keys (as stored in "~/.ssh/authorized_keys").
	$userName = [Environment]::UserName
	$certName = Prompt-Text "Who does this certificate belong to?" -DefaultValue $userName

	$sshPrivateKeyPath = Get-SshPrivateKeyPath -CreateDirIfNotExists $true

	# Parameters:
	# -o : store private key with bcrypt encryption (which makes brute-force decrypting hard)
	# -t : create RSA key
	# -b : use 4096 bits
	# -C : add comment to generated certificate
	# -f : output file
	# See also: http://www.manpagez.com/man/1/ssh-keygen/
	& ssh-keygen -o -t rsa -b 4096 -C "$certName" -f "$sshPrivateKeyPath"
	if (-Not $?) {
		Write-Error 'ssh-keygen failed'
	}

	Ensure-CorrectSshKeyPermissions
}

function Install-SshKey([String] $SshTarget) {
	$sshConfigPath = Ensure-SshConfigIsUpToDate

	$sshPublicKeyPath = Get-SshPublicKeyPath
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

	# Does basically the same thing as "ssh-copy-id". The problem with "ssh-copy-id" is that you can't
	# specify the SSH config file and thus it won't work here.
	#
	# The 'PreferredAuthentications' option (see 'man ssh_config') makes sure the user isn't asked
	# for the password to his/her SSH private key (which may be confusing to the user at this point).
	#
	# For some guidance on this command see:
	# * http://askubuntu.com/a/6186/62255
	# * https://github.com/openssh/openssh-portable/blob/master/contrib/ssh-copy-id
	$publicKey | & ssh -F $sshConfigPath -o 'PreferredAuthentications keyboard-interactive,password' -p $port $SshTarget "exec sh -c 'cd ; umask 077 ; mkdir -p .ssh && cat >> .ssh/authorized_keys || exit 1'"
}

function Check-SshKeyEncryption {
	$sshPrivateKeyPath = Get-SshPrivateKeyPath

	if (-Not (Test-Path $sshPrivateKeyPath)) {
		Write-Host -ForegroundColor Red "ERROR: SSH key pair doesn't exist."
		return
	}

	Write-Host -NoNewline 'Encryption: '
	try {
		& ssh-keygen -p -P [String]::Empty -N [String]::Empty -f $sshPrivateKeyPath 2>&1 | Out-Null
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

function Ensure-CorrectSshKeyPermissions {
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
