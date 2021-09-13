#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Installs and configures Edge for a virtual desktop gold image
#>

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "MicrosoftEdgeEnterpriseX64.msi" -Recurse -ErrorAction = "SilentlyContinue"
    $params = @{
        FilePath     = "$env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" /quiet /norestart DONOTCREATEDESKTOPSHORTCUT=true"
        NoNewWindow  = $True
        Wait         = $True
    }
    Start-Process @params
}
catch {
    Throw "Failed to install Microsoft Edge."
}

# Post install configuration
$prefs = @{
    "homepage"               = "https://www.office.com"
    "homepage_is_newtabpage" = $False
    "browser"                = @{
        "show_home_button" = $True
    }
    "distribution"           = @{
        "skip_first_run_ui"              = $True
        "show_welcome_page"              = $False
        "import_search_engine"           = $False
        "import_history"                 = $False
        "do_not_create_any_shortcuts"    = $False
        "do_not_create_taskbar_shortcut" = $False
        "do_not_create_desktop_shortcut" = $True
        "do_not_launch_chrome"           = $True
        "make_chrome_default"            = $True
        "make_chrome_default_for_user"   = $True
        "system_level"                   = $True
    }
}
$prefs | ConvertTo-Json | Set-Content -Path "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\master_preferences" -Force

Remove-Item -Path "$env:Public\Desktop\Microsoft Edge*.lnk" -Force -ErrorAction "SilentlyContinue"

# Confirm this is OK for your virtual desktop scenario before disabling Edge update services
$services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService"
ForEach ($service in $services) { Get-Service -Name $service | Set-Service -StartupType "Disabled" }
ForEach ($task in (Get-ScheduledTask -TaskName *Edge*)) { Unregister-ScheduledTask -TaskName $Task -Confirm:$False -ErrorAction SilentlyContinue }
