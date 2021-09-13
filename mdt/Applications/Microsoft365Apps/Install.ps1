#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Installs and configures Microsoft 365 Apps for a virtual desktop gold image
#>

Switch -Regex ((Get-WmiObject Win32_OperatingSystem).Caption) {
    "Microsoft Windows Server*" {
        $Config = "SharedDesktopMonthlyEnterprise.xml"
        Break
    }
    "Microsoft Windows 10 Enterprise for Virtual Desktops" {
        $Config = "SharedDesktopMonthlyEnterprise.xml"
        Break
    }
    "Microsoft Windows 10 Enterprise" {
        $Config = "VirtualDesktopMonthlyEnterprise.xml"
        Break
    }
    "Microsoft Windows 10*" {
        $Config = "VirtualDesktopMonthlyEnterprise.xml"
        Break
    }
    Default {
        $Config = "VirtualDesktopMonthlyEnterprise.xml"
    }
}

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "setup.exe" -Recurse -ErrorAction = "SilentlyContinue"
    $Configuration = Get-ChildItem -Path $PWD -Filter $Config -Recurse -ErrorAction = "SilentlyContinue"
    $params = @{
        FilePath     = $Installer.FullName
        ArgumentList = "/configure $($Configuration.FullName)"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
}
catch {
    Throw "Failed to install Microsoft 365 Apps."
}
