# Stop on every error
$script:ErrorActionPreference = 'Stop'

try {
	& $PSScriptRoot/app/SshEnvApp.ps1 @Args
}
finally {
	& $PSScriptRoot/app/Unload-Modules.ps1
}
