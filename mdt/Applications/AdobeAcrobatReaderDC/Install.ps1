#Requires -Modules Evergreen
<#
    .SYNOPSIS
    Installs and configures Adobe Acrobat Reader DC for a virtual desktop gold image
#>
[CmdletBinding()]
Param ()

# Run tasks/install apps
# Enforce settings with GPO: https://www.adobe.com/devnet-docs/acrobatetk/tools/AdminGuide/gpo.html
try {
    $Installer = Get-ChildItem -Path $PWD -Filter "AcroRdrDC*.exe" -Recurse -ErrorAction = "SilentlyContinue"
    $params = @{
        FilePath     = $Installer.FullName
        ArgumentList = "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
}
catch {
    Throw "Failed to install Adobe Acrobat Reader DC."
}

# Run post install actions
$Executables = "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
    "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Acrobat.exe", `
    "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
If (Test-Path -Path $Executables) {

    # Configure update tasks
    Get-Service -Name "AdobeARMservice" -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
    Get-ScheduledTask "Adobe Acrobat Update Task*" | Unregister-ScheduledTask -Confirm:$False -ErrorAction "SilentlyContinue"
}
