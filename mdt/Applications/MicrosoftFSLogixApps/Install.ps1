#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Installs FSLogix Apps for a virtual desktop gold image
#>

try {
    $Destination = "$env:SystemRoot\Temp\FSLogixApps"
    New-Item -Path $Destination -ItemType "Directory" -ErrorAction "SilentlyContinue" > $Null
    $Installer = Get-ChildItem -Path $PWD -Filter "FSLogix*.zip" -Recurse -ErrorAction "SilentlyContinue" | Select-Object -First 1
    Expand-Archive -Path $Installer.FullName -DestinationPath $Destination -Force
    $params = @{
        FilePath     = $([System.IO.Path]::Combine($Destination, "x64", "Release", "FSLogixAppsSetup.exe"))
        ArgumentList = "/install /quiet /norestart"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
}
catch {
    Throw "Failed to install Microsoft FSLogix Apps agent."
}

Remove-Item -Path $Destination -Recurse -Force -ErrorAction "SilentlyContinue"
