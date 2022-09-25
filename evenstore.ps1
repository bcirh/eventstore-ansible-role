# This powershell script installs and configures Eventstore on a single node.

$ESDBversion = "21.10.5"
$NSSMversion = 2.24
$Insecure = 0
$LocalIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet | foreach { $_.IPAddress })
$Workdir = "~/workdir_esdb"
$InstalESDBExporter = 0
$InstalWindowsExporter = 0
$FormatDataDisk = 0

### FORMAT DATA DISK ###

# If the disk is already formated script will throw an Error ParameterArgumentValidationError. This error can be ignored.
if ( $FormatManagedDisk -eq 1 ) {
    $disk = Get-Disk | where-object PartitionStyle -eq "RAW"
    Initialize-Disk -Number $disk.Number -PartitionStyle MBR -confirm:$false
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -IsActive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "esdb" -confirm:$False
    Set-Partition -DiskNumber $disk.Number -PartitionNumber 1 -NewDriveLetter X
}

### END FORMAT MANAGED DISK ###

### CREATE DIRECTORIES ###

mkdir $Workdir -Force

# ESDB Directories
if ( $FormatManagedDisk -eq 1 ) {
$ESDB_Main_Dir = "X:\ESDB"
$ESDB_Data_Dir = "X:\ESDB\Data"
$ESDB_Index_Dir = "X:\ESDB\Index"
$ESDB_Logs_Dir = "X:\ESDB\Logs"
$ESDB_Certs_Dir = "X:\ESDB\certs\ca"
} else {
$ESDB_Main_Dir = "C:\ESDB"
$ESDB_Data_Dir = "C:\ESDB\Data"
$ESDB_Index_Dir = "C:\ESDB\Index"
$ESDB_Logs_Dir = "C:\ESDB\Logs"
$ESDB_Certs_Dir = "C:\ESDB\certs\ca"
}

mkdir $ESDB_Main_Dir -Force
mkdir $ESDB_Data_Dir -Force
mkdir $ESDB_Index_Dir -Force
mkdir $ESDB_Logs_Dir -Force
mkdir $ESDB_Certs_Dir -Force

### END CREATE DIRECTORIES ###

### DOWNLOAD ###

# Run the line below if Invoke-WebRequest fails with Tls error
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
###-----------###

# Download 7zip.exe
Invoke-WebRequest -Uri https://www.7-zip.org/a/7z1900-x64.msi -OutFile  "$Workdir\7zip.msi"
Start-Process -Wait -FilePath $Workdir\7zip.msi -Argument "/quiet" -PassThru

# Download windows-exporter
if ( $InstalWindowsExporter -eq 1 ) {
Invoke-WebRequest -Uri https://github.com/prometheus-community/windows_exporter/releases/download/v0.17.1/windows_exporter-0.17.1-amd64.msi -OutFile  "$Workdir\windows_exporter-0.17.1-amd64.msi"
Start-Process -Wait -FilePath $Workdir\windows_exporter-0.17.1-amd64.msi -Argument "/quiet" -PassThru
}

# Dowload and extract EventStore
Invoke-WebRequest -Uri https://github.com/EventStore/Downloads/raw/master/win/EventStore-OSS-Windows-2019-v$ESDBversion.zip -OutFile "$Workdir\esdb_$ESDBversion.zip"
Expand-Archive -Path "$Workdir\esdb_$ESDBversion.zip" -DestinationPath $Workdir -Force

# Downaload and extract NSSM
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-$NSSMversion.zip" -OutFile "$Workdir\nssm-$NSSMversion.zip"
Expand-Archive -Path "$Workdir\nssm-$NSSMversion.zip" -DestinationPath $Workdir -ErrorAction SilentlyContinue

# Download and extract es-cert-generator tool
Invoke-WebRequest -Uri https://github.com/EventStore/es-gencert-cli/releases/download/1.0.2/es-gencert-cli_1.0.2_Windows-x86_64.zip -OutFile "$Workdir\es-gencert-cli_1.0.2_Windows-x86_64.zip"
Expand-Archive -Path "$Workdir\es-gencert-cli_1.0.2_Windows-x86_64.zip" -DestinationPath $Workdir\es-gencert -Force

# Download ES-exporter
if ( $InstalESDBExporter -eq 1 ) {
Invoke-WebRequest -Uri https://github.com/marcinbudny/eventstore_exporter/releases/download/v0.10.4/eventstore_exporter_0.10.4_Windows_x86_64.tar.gz -OutFile "$Workdir\eventstore_exporter_0.10.4_Windows_x86_64.tar.gz"
Set-Location 'C:\Program Files\7-Zip'
Move-Item -Path $Workdir\eventstore_exporter_0.10.4_Windows_x86_64.tar.gz -Destination C:\ -Force
.\7z.exe x C:\eventstore_exporter_0.10.4_Windows_x86_64.tar.gz -oc:\ -y
.\7z.exe x C:\eventstore_exporter_0.10.4_Windows_x86_64.tar -oc:\eventstore-exporter -y
}

### END DOWNLOAD ###


### CREATE CERT ###

# Create certificates for ESDB
if ( $Insecure -eq 0 ) {
Set-Location -Path "$Workdir\es-gencert"
mkdir certs -Force
# Generate CA cert for ESDB
.\es-gencert-cli create-ca -out .\certs\ca

foreach ($i in $LocalIP) {
    .\es-gencert-cli create-node -ca-certificate .\certs\ca\ca.crt -ca-key .\certs\ca\ca.key -out .\certs\$i  -ip-addresses $i
    }
}

### END CREATE CERT ###

### Copy Cert ###
Copy-Item .\certs\ca\ca.crt $ESDB_Main_Dir\certs\ca
Copy-Item -Recurse .\certs\$LocalIP\* $ESDB_Main_Dir\certs

### CREATE EVENTSTORE CONFIGURATION ###

# Create eventstore.conf file
$ESDBconf = "$ESDB_Main_Dir\eventstore.conf"
New-Item $ESDBconf -ItemType File -Force -ErrorAction SilentlyContinue
Add-Content $ESDBconf "---"
Add-Content $ESDBconf "# Paths"
Add-Content $ESDBconf "Db: $ESDB_Data_Dir"
Add-Content $ESDBconf "Index: $ESDB_Index_Dir"
Add-Content $ESDBconf "Log: $ESDB_Logs_Dir"
Add-Content $ESDBconf "`r`n"
# Certificates configuration
if ( $Insecure -eq 1 ) {
Add-Content $ESDBconf "Insecure: true"
}
elseif ( $Insecure -eq 0 ) {
Add-Content $ESDBconf "# Certificates configuration"
Add-Content $ESDBconf "CertificateFile: $ESDB_Main_Dir\certs\node.crt"
Add-Content $ESDBconf "CertificatePrivateKeyFile: $ESDB_Main_Dir\certs\node.key"
Add-Content $ESDBconf "TrustedRootCertificatesPath: $ESDB_Certs_Dir"
}
Add-Content $ESDBconf "`r`n"
# Networking configuration
Add-Content $ESDBconf "# Networking configuration"
Add-Content $ESDBconf "IntIp: $LocalIP"
Add-Content $ESDBconf "ExtIp: $LocalIP"
Add-Content $ESDBconf "IntTcpPort: 1112"
Add-Content $ESDBconf "ExtTcpPort: 1113"
Add-Content $ESDBconf "HttpPort: 2113"
Add-Content $ESDBconf "EnableExternalTcp: true"
Add-Content $ESDBconf "EnableAtomPubOverHTTP: true"
Add-Content $ESDBconf "`r`n"
# Projections configuration
Add-Content $ESDBconf "# Projections configuration"
Add-Content $ESDBconf "RunProjections: All"

### END CREATE EVENTSTORE CONFIGURATION ###

### CREATE SERVICES ###

# Create eventstore-exporter service. This will promt for user input.
if ( $InstalESDBExporter -eq 1 ) {
Set-Location $Workdir\nssm-$NSSMversion\win64
.\nssm.exe install EventStore-Exporter
}

#Create ESDB 21.10.5 service

Move-Item -Path $Workdir\EventStore-OSS-Windows-2019-v$ESDBversion -Destination C:\ -Force -ErrorAction SilentlyContinue
Set-Location $Workdir\nssm-$NSSMversion\win64
.\nssm.exe install EventStoreDB C:\EventStore-OSS-Windows-2019-v${ESDBversion}\EventStore.ClusterNode.exe --config C:\ESDB\eventstore.conf

.\nssm.exe start EventStoreDB

### END CREATE SERVICES ###

Write-Host "Access Eventstore from your browser on http(s)://${LocalIP}:2113"
