#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Install Features on Demand
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String[]] $Language = @("en-AU", "en-GB"),

    [Parameter()]
    [System.String] $Source = $PWD,

    [Parameter()]
    [System.String] $Build = ([System.Environment]::OSVersion.Version).Build
)

# Log file
$stampDate = Get-Date
$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:SystemRoot\Logs\$scriptName-" + $stampDate.ToFileTimeUtc() + ".log"
Start-Transcript -Path $logFile

# Install language packages based on the system locale, unless -Language parameter specifies languages
If ($PSBoundParameters.ContainsKey('Language')) {
    [System.String[]] $InstallLanguages = $Language
}
Else {
    $SystemLocale = (Get-WinSystemLocale).Name
    Switch ($SystemLocale) {
        "en-AU" { [System.String[]] $InstallLanguages = @("en-AU", "en-GB") }
        Default { $InstallLanguages = $SystemLocale }
    }
}

# Install packages
ForEach ($Language in $InstallLanguages) {
    Write-Verbose -Message "$($MyInvocation.MyCommand): Adding packages for [$Language]."
    $Capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Language*$Language*" }
    ForEach ($Capability in $Capabilities) {
        try {
            Add-WindowsCapability -Online -Name $Capability.Name -Source "$Source\$Build" -LimitAccess
        }
        catch {
            Throw "Failed to add capability: $($Capability.Name)."
        }
    }
}

# End log
Stop-Transcript
