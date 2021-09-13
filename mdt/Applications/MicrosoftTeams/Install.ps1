#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Installs and configures Teams for a virtual desktop gold image
#>

try {
    reg add "HKLM\SOFTWARE\Microsoft\Teams" /v "IsWVDEnvironment" /t REG_DWORD /d 1
    reg add "HKLM\SOFTWARE\Citrix\PortICA" /v "IsWVDEnvironment" /t REG_DWORD /d 1
    $Installer = Get-ChildItem -Path $PWD -Filter "MicrosoftEdgeEnterpriseX64.msi" -Recurse -ErrorAction = "SilentlyContinue"
    $params = @{
        FilePath     = "$env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSER=1 ALLUSERS=1 OPTIONS=`"noAutoStart=true`" /quiet"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
    Remove-Item -Path "$env:Public\Desktop\Microsoft Teams.lnk" -Force -ErrorAction SilentlyContinue
}
catch {
    Throw "Failed to install Microsoft Teams."
}

# Teams JSON files
$Paths = @((Join-Path -Path "${env:ProgramFiles(x86)}\Teams Installer" -ChildPath "setup.json"), 
    (Join-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -ChildPath "setup.json"))

# Read the file and convert from JSON
ForEach ($Path in $Paths) {
    try {
        $Json = Get-Content -Path $Path | ConvertFrom-Json
        $Json.noAutoStart = $true
        $Json | ConvertTo-Json | Set-Content -Path $Path -Force
    }
    catch {
        Throw "Failed to set Teams autostart file: $Path."
    }
}

# Delete the registry auto-start
REG DELETE "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" /v "Teams" /f
