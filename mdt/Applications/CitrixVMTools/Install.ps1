#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Installs and configures Citrix VM Tools for a virtual desktop gold image
#>

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "managementagentx64.msi" -Recurse -ErrorAction = "SilentlyContinue"
    $params = @{
        FilePath     = "$env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLOWAUTOUPDATE=YES ALLOWDRIVERINSTALL=YES ALLOWDRIVERUPDATE=NO IDENTIFYAUTOUPDATE=YES /quiet /norestart"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
}
catch {
    Throw "Failed to install Microsoft Edge."
}
