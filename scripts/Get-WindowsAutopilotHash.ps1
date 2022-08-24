Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted" -Force
Install-Script -Name "Get-WindowsAutopilotInfo" -Force
New-Item -Path "$env:SystemDrive\Temp" -ItemType "Directory" -ErrorAction "SilentlyContinue"
Get-WindowsAutopilotInfo.ps1 -OutputFile "$env:SystemDrive\Temp\$env:ComputerName.csv"
