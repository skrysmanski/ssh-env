# Stop on every error
$script:ErrorActionPreference = 'Stop'

function Test-IsPosix {
	return $IsMacOs -or $IsLinux
}

function Test-IsWindows {
	return  [System.Environment]::OSVersion.Platform -eq 'Win32NT'
}

$script:Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

# NOTE: This function is necessary on PowerShell versions less than 6.0. Starting with
#   6.0, the default utf8 encoding doesn't seem to include the BOM anymore.
# NOTE 2: This method does get its contents from a pipeline because this would make the
#   code unnecessary complicated to read.
function Write-FileUtf8NoBom([string] $FilePath, $Contents) {
	# NOTE: We can't use the Out-File cmdlet here as it doesn't accept a custom encoding.
	if ($Contents.GetType() -eq [string]) {
		[IO.File]::WriteAllText($FilePath, $Contents, $script:Utf8NoBomEncoding)
	}
	else {
		[IO.File]::WriteAllLines($FilePath, $Contents, $script:Utf8NoBomEncoding)
	}
}

function Write-FileUtf8NoBomWithSecurePermissions([String] $FilePath, $Contents, [String] $PosixFilePermissions = '0600') {
	if (Test-IsPosix) {
		# We make sure that the file permissions are set BEFORE the file is filled with content.
		if (-Not (Test-Path $FilePath -PathType Leaf)) {
			'' | Out-File $FilePath
		}

		& chmod $PosixFilePermissions $FilePath
	}

	Write-FileUtf8NoBom -FilePath $FilePath -Contents $Contents
}

# Synchronizes the .NET working directory with the PowerShell working directory (which - for
# whatever reason - is not synchronized automatically). This difference is, for example, visible
# when using "[Io.Path]::GetFullPath()" on a relative path.
function Sync-CurrentWorkingDirectory {
	$powershellCwd = (Get-Location -PSProvider FileSystem).ProviderPath
	[Environment]::CurrentDirectory = $powershellCwd
}

function Test-IsFolderEncrypted([string] $FolderPath) {
	if (Test-IsWindows) {
		if ((Get-ItemProperty $FolderPath).attributes -match "Encrypted") {
			return $true
		}
		else {
			return $false
		}
	}

	# Unsupported OS.
	return $null
}

function Read-ChoicePrompt($Prompt, [string[]] $Choices, [string] $DefaultValue = $null) {
	if ((-Not $Choices) -or ($Choices.Length -eq 0)) {
		throw "No choices specified."
	}

	while ($true) {
		$input = Read-Host $Prompt

		if ($input -in $Choices) {
			return $input
		}
		elseif (($input -eq '') -and $DefaultValue) {
			return $DefaultValue
		}
	}
}

function Read-YesNoPrompt($Prompt, $DefaultValue = $null) {
	if ($DefaultValue -eq $true) {
		$choiceText = '(Y/n)'
		$DefaultValue = 'y'
	}
	elseif ($DefaultValue -eq $false) {
		$choiceText = '(y/N)'
		$DefaultValue = 'n'
	}
	else {
		$choiceText = '(y/n)'
		$DefaultValue = $null
	}

	$response = Read-ChoicePrompt "$Prompt $choiceText" -Choices @('y', 'n') -DefaultValue $DefaultValue
	return $response -eq 'y'
}

function Read-IntegerPrompt($Prompt, [int] $DefaultValue = $null) {
	if ($DefaultValue -ne $null) {
		$Prompt += " [$DefaultValue]"
	}

	while ($true) {
		$input = Read-Host $Prompt

		if ($input -match '^[0-9]+$') {
			# Valid input. Convert from string to int.
			return [int]$input
		}
		elseif (($input -eq '') -and ($DefaultValue -ne $null)) {
			return $DefaultValue
		}
	}
}

function Read-TextPrompt($Prompt, [bool] $AllowEmpty = $false, [string] $DefaultValue = $null) {
	if ($DefaultValue) {
		$Prompt += " [$DefaultValue]"
	}

	while ($true) {
		$input = Read-Host $Prompt

		if ($input -ne '') {
			return $input
		}
		else {
			if ($DefaultValue) {
				return $DefaultValue
			}
			elseif ($AllowEmpty) {
				return ''
			}
		}
	}
}

function Test-IsFolderEmpty([string] $Path) {
	return ((Get-ChildItem $Path -force | Select-Object -First 1 | Measure-Object).Count -eq 0)
}
