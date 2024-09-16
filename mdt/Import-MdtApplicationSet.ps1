#Requires -RunAsAdministrator
<# 
    .SYNOPSIS
        Download applications for import into an MDT share
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]    
    [System.String] $DeploymentShare = "E:\Deployment\Automata",

    [Parameter(Mandatory = $false)]
    [System.String] $RepoPath = "C:\Projects\automata",

    [Parameter(Mandatory = $false)]
    [System.String] $Definition = "C:\Projects\automata\mdt\Applications.json",

    [Parameter(Mandatory = $false)]
    [System.String] $Source = "C:\Projects\automata\mdt\Applications",

    [Parameter(Mandatory = $false)]
    [System.String] $DownloadPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [System.String] $Drive = "DS002"
)

#region Import the MDT PowerShell module
try {
    Write-Host -ForegroundColor "Cyan" -Object "Import module: MicrosoftDeploymentToolkit"
    $VerbosePref = $VerbosePreference
    $VerbosePreference = "SilentlyContinue"
    $MdtReg = Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Deployment 4" -ErrorAction "SilentlyContinue"
    Import-Module $([System.IO.Path]::Combine($MdtReg.Install_Dir, "bin", "MicrosoftDeploymentToolkit.psd1"))
    $VerbosePreference = $VerbosePref
}
catch {
    throw $_
}
#endregion

#region Update modules
$Repository = "PSGallery"
if (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
    try {
        Write-Host -ForegroundColor "Cyan" -Object "Trust repository: PSGallery"
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
        Set-PSRepository -Name $Repository -InstallationPolicy "Trusted"
    }
    catch {
        throw $_
    }
}

$Modules = "Evergreen", "VcRedist"
foreach ($module in $Modules) {
    try {
        $installedModule = Get-Module -Name $module -ListAvailable | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
            Select-Object -First 1
        $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
        if (($Null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
            Write-Host -ForegroundColor "Cyan" -Object "Install module: $module"
            $params = @{
                Name               = $module
                SkipPublisherCheck = $true
                Force              = $true
                ErrorAction        = "Stop"
            }
            Install-Module @params
            Import-Module -Name $module -Force
        }
    }
    catch {
        throw $_
    }
}
#endregion

#region Mount the Deployment Share
Restore-MdtPersistentDrive
$psDrive = Get-MdtPersistentDrive | Where-Object { $_.Path -eq $DeploymentShare } | Select-Object -First 1
if ($Null -eq $psDrive) {
    try {
        Write-Host -ForegroundColor "Cyan" -Object "Connect to MDT deployment share"
        $params = @{
            Name       = $Drive
            PSProvider = "MDTProvider"
            Root       = $DeploymentShare
        }
        New-PSDrive @params | Add-MDTPersistentDrive
        $psDrive = Get-MdtPersistentDrive | Where-Object { $_.Path -eq $DeploymentShare -and $_.Name -eq $Drive } | Select-Object -First 1
        Restore-MdtPersistentDrive
    }
    catch [System.Exception] {
        Write-Warning -Message "$($MyInvocation.MyCommand): Failed to create MDT drive at: [$DeploymentShare]."
        throw $_.Exception.Message
    }
}
#endregion


#region Read the application definition manifest JSON file
try {
    $Applications = Get-Content -Path $Definition | ConvertFrom-Json
}
catch {
    throw $_
}
#endregion

#region Walk through JSON and import applications
foreach ($Publisher in $Applications.Publishers | Get-Member -MemberType "NoteProperty") {
    foreach ($App in $Applications.Publishers.($Publisher.Name) | Get-Member -MemberType "NoteProperty") {

        $Properties = $Applications.Publishers.($Publisher.Name).($App.Name)
        Write-Host -ForegroundColor "Cyan" -Object "Search: $($App.Name)."
        $AppUpdate = Invoke-Expression -Command $Properties.Filter
        $ExistingApp = Get-ChildItem -Path "$($psDrive.Name):\Applications" | Where-Object { $_.ShortName -eq $Properties.ShortName -and $_.Version -eq $AppUpdate.Version }

        if ([System.Version] $AppUpdate.Version -lt [System.Version] $ExistingApp.Version) {
            Write-Host -ForegroundColor "Cyan" -Object "Application: $($App.Name) $($AppUpdate.Version) is lower than existing: $($ExistingApp.Name) $($ExistingApp.Version)."
        }
        elseif ([System.Version] $AppUpdate.Version -eq [System.Version] $ExistingApp.Version) {
            Write-Host -ForegroundColor "Cyan" -Object "Application exists: $($App.Name) $($AppUpdate.Version)."
        }
        else {
            Write-Host -ForegroundColor "Cyan" -Object "Importing application: $($App.Name) $($AppUpdate.Version)."
            New-Item -Path $(Join-Path -Path $DownloadPath -ChildPath $($App.Name)) -ItemType "Directory" -ErrorAction "SilentlyContinue" > $Null
            $Download = Save-EvergreenApp -Path $(Join-Path -Path $DownloadPath -ChildPath $($App.Name)) -InputObject $AppUpdate
            Get-ChildItem -Path $Download.DirectoryName -Recurse | Unblock-File

            #region Import the app
            try {
                $params = @{
                    Path                  = "$($psDrive.Name):\Applications"
                    Enable                = "True"
                    Reboot                = $false
                    Name                  = "$($Publisher.Name) $($Properties.ShortName) $($AppUpdate.Version)"
                    ShortName             = $Properties.ShortName
                    Version               = $AppUpdate.Version
                    Publisher             = $Publisher.Name
                    Language              = $Properties.Language
                    CommandLine           = $($Properties.Command -replace "#Installer", $Download.Name )
                    WorkingDirectory      = ".\Applications\$($Publisher.Name)\$($Properties.ShortName -replace " ")\$($AppUpdate.Version)"
                    ApplicationSourcePath = $Download.DirectoryName
                    DestinationFolder     = "$($Publisher.Name)\$($Properties.ShortName -replace " ")\$($AppUpdate.Version)"
                }
                Import-MDTApplication @params
            }
            catch {
                throw $_
            }
            #endregion

            #region Copy additional files
            $Destination = $([System.IO.Path]::Combine($DeploymentShare, "Applications", $Publisher.Name, $($Properties.ShortName -replace " "), $AppUpdate.Version))
            if (Test-Path -Path $(Join-Path -Path $Source -ChildPath $($App.Name))) {
                if (Test-Path -Path $Destination) {
                    try {
                        Write-Host -ForegroundColor "Cyan" -Object "Copy: $Source to $Destination."
                        $params = @{
                            Path        = $(Join-Path -Path $Source -ChildPath $($App.Name))
                            Destination = $Destination
                            Filter      = "*"
                            Container   = $false
                            Recurse     = $True
                            Force       = $True
                        }
                        Copy-Item @params
                    }
                    catch {
                        Write-Warning -Message "Failed to copy from: $Source."
                    }
                }
                else {
                    Write-Warning -Message "Skip copy. Folder does not exist: $Destination."
                }
            }
            #endregion

            #region Run a process
            if ($Properties.PostImport) {
                Push-Location -Path $Destination
                $params = @{
                    FilePath     = $Properties.PostImport.FilePath
                    ArgumentList = $Properties.PostImport.ArgumentList
                    NoNewWindow  = $True
                    Wait         = $True
                    Verbose      = $True
                }
                Start-Process @params
                Pop-Location
            }
            #endregion
        }

        # Remove the variable so that next run we don't inadvertently compare with the previous app
        Remove-Variable -Name "ExistingApp" -ErrorAction "SilentlyContinue"
    }
}
#endregion

#region VcRedists; Download the VcRedists & add to the deployment share
Write-Host -ForegroundColor "Cyan" -Object "Importing Microsoft Visual C++ Redistributables."
$VcPath = Join-Path -Path $DownloadPath -ChildPath "VcRedists"
New-Item -Path $VcPath -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
Get-VcList | Save-VcRedist -Path $VcPath | Import-VcMdtApplication -MdtPath $DeploymentShare -Silent
New-VcMdtBundle -MdtPath $DeploymentShare
#endregion

Write-Host -ForegroundColor "Cyan" -Object "Import complete."
