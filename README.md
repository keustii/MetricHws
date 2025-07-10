# Monitoring System Metrics

## English

This repository contains a PowerShell script that collects hardware metrics on Windows machines and exports them to a CSV file. It reports CPU, RAM, disk, network, and GPU information. The script is intended for deployments across multiple workstations.

### Features
- Collects real-time hardware data 🖥️
- Supports French and English counters 🇬🇧🇫🇷
- Exports results to a centralized CSV file 📄

### Usage
1. Edit the `$csvFolder` variable in `metrics.ps1` to specify the UNC path where CSV files will be stored.
2. Run the script on the target machine using PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File metrics.ps1
   ```
3. Check the generated CSV file for collected metrics.

## Français

Ce dépôt contient un script PowerShell qui collecte les métriques matérielles sur les postes Windows et les exporte dans un fichier CSV. Il fournit des informations sur le CPU, la RAM, les disques, le réseau et les GPU. Le script est prévu pour un déploiement sur plusieurs postes.

### Fonctionnalités
- Collecte des données matérielles en temps réel 🖥️
- Compatibilité avec les compteurs français et anglais 🇬🇧🇫🇷
- Export des résultats dans un fichier CSV centralisé 📄

### Utilisation
1. Modifiez la variable `$csvFolder` dans `metrics.ps1` pour définir le chemin UNC où seront stockés les fichiers CSV.
2. Exécutez le script sur la machine cible avec PowerShell :
   ```powershell
   powershell -ExecutionPolicy Bypass -File metrics.ps1
   ```
3. Consultez le fichier CSV généré pour voir les métriques collectées.

