# Stop on every error
$script:ErrorActionPreference = 'Stop'

$REPO_URL = 'https://github.com/skrysmanski/ssh-env'

$gitCommand = Get-Command 'git' -ErrorAction SilentlyContinue
if (-Not $gitCommand) {
	Write-Host -ForegroundColor Red "ERROR: Git is not installed"
	Write-Host -ForegroundColor Red "Check $REPO_URL#required-software for details."
	exit 1
}

Write-Host "Installing ssh-env..."
Write-Host
$installDir = Read-Host "Where do you want to install ssh-env? [~/ssh-env]"

if (-Not $installDir) {
	$installDir = '~/ssh-env'
}

# Replace ~ with $HOME so that this actually works.
$installDir = $installDir.Replace('~', "$env:HOMEDRIVE$env:HOMEPATH")

if (Test-Path $installDir) {
	Write-Host -ForegroundColor Red "ERROR: This directory already exists."
	exit 1
}

Write-Host

# --depth=1 only grabs the newest revision
& git clone --depth=1 "$REPO_URL.git" $installDir
if (-Not $?) {
	Write-Host -ForegroundColor Red "ERROR: git clone of ssh-env repo failed"
	exit 1
}

Write-Host
Write-Host "ssh-env has been installed successfully"
