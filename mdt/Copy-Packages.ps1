<#
    .SYNOPSIS
        Copies the required Windows Features on Demand into a target folder; Requires the Features on Demand ISO
        Call Install-FeaturesOnDemand.ps1 during a task sequence to install
  
    .LINK
        http://stealthpuppy.com
#>
[CmdletBinding(SupportsShouldProcess = $False)]
Param (
    [Parameter(Mandatory = $False)]
    [System.String] $Path = "F:\LanguagesAndOptionalFeatures",

    [Parameter(Mandatory = $False)]
    [System.String] $Destination = "D:\Temp\MicrosoftFoD",

    [Parameter(Mandatory = $False)]
    [System.String] $Build = "20348",

    [Parameter(Mandatory = $False)]
    [System.String] $Language = "en-GB|en-AU"
)

# Create the target folder
$params = @{
    Path        = [System.IO.Path]::Combine($Destination, $Build, "metadata")  #"D:\Temp\MicrosoftFoD\20348\metadata"
    ItemType    = "Directory"
    ErrorAction = "SilentlyContinue"
}
New-Item @params | Out-Null

# Copy the feature CAB files
$Files = @(
    "FoDMetadata_Client.cab"
    "Microsoft-Windows-LanguageFeatures-Basic-($Language|en-US)-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-LanguageFeatures-Handwriting-($Language|en-US)-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-LanguageFeatures-OCR-($Language|en-US)-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-LanguageFeatures-Speech-($Language|en-US)-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-LanguageFeatures-TextToSpeech-($Language|en-US)-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-Server-Language-Pack_x64_($Language|en-US).cab"
    "Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~($Language|en-US)~.cab"
    "Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~($Language|en-US)~.cab"
    "Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~~.cab"
    "Microsoft-Windows-UserExperience-Desktop-Package~31bf3856ad364e35~amd64~~.cab"
)
ForEach ($File in $Files) {
    Get-ChildItem -Path $Path | `
        Where-Object -FilterScript { $_.Name -match $File } | `
        Copy-Item -Destination $([System.IO.Path]::Combine($Destination, $Build)) -ErrorAction "SilentlyContinue"
}

# Copy the metadata files
Get-ChildItem -Path $([System.IO.Path]::Combine($Path, "metadata")) | `
    Where-Object -FilterScript { $_.Name -match ".*(Neutral|$Language|en-US).xml.cab" } | `
    Copy-Item -Destination $([System.IO.Path]::Combine($Destination, $Build, "metadata")) -ErrorAction "SilentlyContinue"
