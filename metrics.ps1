####################################################################
# MONITORING SYSTÈME - COLLECTE MÉTRIQUES HARDWARE
# Date: 07/07/2025 | Version: 1.0 | Auteur: KeuStii
# Entreprise: XXX 
# Description: Collecte automatisée des métriques système et export CSV centralisé
# Déploiement: Production multi-postes
####################################################################


$ErrorActionPreference = "SilentlyContinue"


# Configuration export CSV - Modifiez juste ce chemin
$csvFolder = "\\serverfichier\commun\Metrics"  # Mettez votre chemin UNC ici
$csvPath = "$csvFolder\$($env:COMPUTERNAME)_hwinfo-.csv"

# Langue FR ou EN
$useFR = (Get-Counter -ListSet "Mémoire") -ne $null

# Définition des compteurs selon langue
$counters = if ($useFR) {
    @{
        cpu       = '\Processeur(_Total)\% Temps processeur'
        ram_free  = '\Mémoire\Mégaoctets disponibles'
        disk_r    = '\Disque physique(_Total)\Lectures disque/s'
        disk_w    = '\Disque physique(_Total)\Écritures disque/s'
        net_in    = '\Interface réseau(*)\Octets reçus/s'
        net_out   = '\Interface réseau(*)\Octets envoyés/s'
    }
} else {
    @{
        cpu       = '\Processor(_Total)\% Processor Time'
        ram_free  = '\Memory\Available MBytes'
        disk_r    = '\PhysicalDisk(_Total)\Disk Reads/sec'
        disk_w    = '\PhysicalDisk(_Total)\Disk Writes/sec'
        net_in    = '\Network Interface(*)\Bytes Received/sec'
        net_out   = '\Network Interface(*)\Bytes Sent/sec'
    }
}

function Get-Cooked($path) {
    try {
        return (Get-Counter $path -SampleInterval 1 -MaxSamples 1).CounterSamples
    } catch {
        return $null
    }
}

# === INFOS FIXES ===
Write-Host "========================================"
Write-Host "         CONFIGURATION SYSTÈME"
Write-Host "========================================`n"

# Nom du poste
$computerName = $env:COMPUTERNAME
Write-Host "💻 Nom du poste : $computerName"

# CPU - Récupérer le nom complet du processeur
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = $cpuInfo.Name.Trim()
$cpuCores = $cpuInfo.NumberOfLogicalProcessors
Write-Host "🧠 CPU : $cpuName ($cpuCores cœurs logiques)"

# RAM totale (en GB)
$ramTotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$ramTotalMB = [math]::Round($ramTotalGB * 1024, 0)
Write-Host "💾 RAM totale : $ramTotalGB GB"

# GPU - Afficher TOUS les GPU et séparer NVIDIA des autres
Write-Host "🖥️ GPU detectes :"
$gpuList = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -ne $null -and $_.Name -ne "" }
$gpuNvidiaName = "N/A"
$gpuOtherName = "N/A"

$gpuList | ForEach-Object {
    $gpuName = $_.Name
    $gpuRAM = if ($_.AdapterRAM) { [math]::Round($_.AdapterRAM / 1GB, 1) } else { "N/A" }
    Write-Host "  - $gpuName ($gpuRAM GB)"
    
    # Séparer GPU NVIDIA des autres
    if ($gpuName -match "NVIDIA|GeForce|Quadro|Tesla|RTX|GTX") {
        if ($gpuNvidiaName -eq "N/A") {
            $gpuNvidiaName = $gpuName
        }
    } else {
        if ($gpuOtherName -eq "N/A") {
            $gpuOtherName = $gpuName
        }
    }
}

# Disques
Write-Host "`n📀 Disques (Taille & Occupation)"
Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $letter = $_.DeviceID
    $total = [math]::Round($_.Size / 1GB, 1)
    $free = [math]::Round($_.FreeSpace / 1GB, 1)
    $used = [math]::Round($total - $free, 1)
    $percent = if ($_.Size -ne 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
    Write-Host "  - $letter : $used/$total GB utilisés ($percent`%)"
}

# === METRIQUES TEMPS RÉEL ===
Write-Host "`n========================================"
Write-Host "     MÉTRIQUES TEMPS RÉEL (1s)"
Write-Host "========================================"

# CPU
$cpu = Get-Cooked $counters.cpu | Select-Object -ExpandProperty CookedValue

# RAM disponible
$ramFree = Get-Cooked $counters.ram_free | Select-Object -ExpandProperty CookedValue
# RAM utilisée = Total - Disponible
$ramUsed = $ramTotalMB - $ramFree

# Disques
$diskR = Get-Cooked $counters.disk_r | Select-Object -ExpandProperty CookedValue
$diskW = Get-Cooked $counters.disk_w | Select-Object -ExpandProperty CookedValue

# Réseau
$netIn = Get-Cooked $counters.net_in | Where-Object { $_.InstanceName -notmatch "Loopback|isatap" } | Sort-Object CookedValue -Descending | Select-Object -First 1
$netOut = Get-Cooked $counters.net_out | Where-Object { $_.InstanceName -eq $netIn.InstanceName } | Select-Object -First 1

# GPU usage et température - NVIDIA et Autres séparément
$gpuNvidia = 0
$gpuNvidiaTemp = "N/A"
$gpuAutre = 0

# NVIDIA via nvidia-smi
try {
    # Utilisation GPU
    $nvidiaResult = cmd /c "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>nul"
    if ($nvidiaResult -and $nvidiaResult.Trim() -match '^\d+$') {
        $gpuNvidia = [double]$nvidiaResult.Trim()
    }
    
    # Température GPU NVIDIA
    $nvidiaTempResult = cmd /c "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>nul"
    if ($nvidiaTempResult -and $nvidiaTempResult.Trim() -match '^\d+$') {
        $gpuNvidiaTemp = [int]$nvidiaTempResult.Trim()
    }
} catch { }

# Autres GPU via Get-Counter
try {
    $result = (Get-Counter '\GPU Engine(*)\Utilization Percentage' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop).CounterSamples | Measure-Object -Property CookedValue -Average | Select-Object -ExpandProperty Average
    if ($result) { $gpuAutre = $result }
} catch { }

# Affichage final
Write-Host "`n🔁 Données collectées sur 1 seconde :"
Write-Host "🧠 CPU utilisé        : $([math]::Round($cpu,2)) %"
Write-Host "💾 RAM utilisée       : $([math]::Round($ramUsed,2)) MB ($([math]::Round($ramUsed/1024,2)) GB)"
Write-Host "💡 RAM disponible     : $([math]::Round($ramFree,2)) MB ($([math]::Round($ramFree/1024,2)) GB)"
Write-Host "📈 Disque lectures    : $([math]::Round($diskR,2)) /s"
Write-Host "📉 Disque écritures   : $([math]::Round($diskW,2)) /s"
Write-Host "📥 Réseau entrant     : $([math]::Round($netIn.CookedValue / 1024, 2)) KB/s ($($netIn.InstanceName))"
Write-Host "📤 Réseau sortant     : $([math]::Round($netOut.CookedValue / 1024, 2)) KB/s"
Write-Host "🎮 GPU NVIDIA utilisé  : $([math]::Round($gpuNvidia, 2)) % ($gpuNvidiaTemp°C)"
Write-Host "🔧 GPU Autre utilisé   : $([math]::Round($gpuAutre, 2)) %"

Write-Host "`n✅ Monitoring terminé."

# === EXPORT CSV ===
# Préparer les données pour le CSV
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$csvData = [PSCustomObject]@{
    DateTime = $timestamp
    ComputerName = $computerName
    CpuName = $cpuName
    CpuCoresAmount = $cpuCores
    CpuUsagePercent = [math]::Round($cpu, 2)
    RamTotalMB = $ramTotalMB
    RamUsedMB = [math]::Round($ramUsed, 2)
    RamAvailableMB = [math]::Round($ramFree, 2)
    DiskReadsPerSec = [math]::Round($diskR, 2)
    DiskWritesPerSec = [math]::Round($diskW, 2)
    NetworkInKBps = [math]::Round($netIn.CookedValue / 1024, 2)
    NetworkOutKBps = [math]::Round($netOut.CookedValue / 1024, 2)
    NetworkInterface = $netIn.InstanceName
    GpuNvidiaName = $gpuNvidiaName
    GpuNvidiaPercent = [math]::Round($gpuNvidia, 2)
    GpuNvidiaTempC = $gpuNvidiaTemp
    GpuOtherName = $gpuOtherName
    GpuOtherPercent = [math]::Round($gpuAutre, 2)
}

# Vérifier si le fichier CSV existe déjà
if (Test-Path $csvPath) {
    # Fichier existe : ajouter la ligne
    $csvData | Export-Csv -Path $csvPath -Append -NoTypeInformation -Encoding UTF8
    Write-Host "📄 Données ajoutées au fichier : $csvPath"
} else {
    # Fichier n'existe pas : créer avec headers
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "📄 Fichier CSV créé : $csvPath"
}