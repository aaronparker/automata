Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force
Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
Install-Module -Name "PSWindowsUpdate" -Force
Import-Module -Name "PSWindowsUpdate"
Install-WindowsUpdate -AcceptAll -MicrosoftUpdate -IgnoreReboot
