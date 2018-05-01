# Stop on every error
$script:ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/SshEnvPaths.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/SshConfig.psm1" -DisableNameChecking

function Invoke-Ssh {
	[CmdletBinding(PositionalBinding=$false)]
	Param (
		[parameter(ValueFromPipeline)]
		[String] $PipeIn = $null,

		[Parameter(ValueFromRemainingArguments)]
		[String[]] $OtherArgs
	)

	$sshConfigPath = Ensure-SshConfigIsUpToDate

	if ($PipeIn) {
		$PipeIn | & ssh -F $sshConfigPath @OtherArgs
	}
	else {
		& ssh -F $sshConfigPath @OtherArgs
	}
}
