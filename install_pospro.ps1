#requires -Version 5.1

<#
  Instalador de POS Pro.

  Busca la compilacion mas reciente dentro de .\dist, la instala en
  C:\Apps\pospro y crea un acceso directo en el escritorio.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host 'Se requieren permisos de administrador. Mostrando la ventana de UAC...'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    $elevatedProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    exit $elevatedProcess.ExitCode
}

$projectRoot = Split-Path -Parent $PSCommandPath
$distRoot = Join-Path $projectRoot 'dist'
$buildScript = Join-Path $projectRoot 'build_pospro.bat'
$installRoot = 'C:\Apps'
$installPath = Join-Path $installRoot 'pospro'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Effica.lnk'

try {
    if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
        throw "No se encontro el script de compilacion: $buildScript"
    }

    Write-Host 'Generando la compilacion de Effica...'
    & cmd.exe /c "`"$buildScript`""
    if ($LASTEXITCODE -ne 0) {
        throw "La compilacion fallo. Codigo: $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $distRoot -PathType Container)) {
        throw "No se encontro la carpeta de compilaciones: $distRoot"
    }

    $build = Get-ChildItem -LiteralPath $distRoot -Directory |
        Where-Object {
            $_.Name -like 'pospro_*' -and
            (Test-Path -LiteralPath (Join-Path $_.FullName 'pospro\pospro.exe'))
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $build) {
        throw 'La compilacion termino, pero no genero una carpeta valida en dist.'
    }

    $sourcePath = Join-Path $build.FullName 'pospro'
    $sourceIcon = Join-Path $sourcePath '_internal\app\share\pos-icon-01.ico'

    if (-not (Test-Path -LiteralPath $sourceIcon -PathType Leaf)) {
        throw "La compilacion no contiene el icono requerido: $sourceIcon"
    }

    if (Get-Process -Name 'pospro' -ErrorAction SilentlyContinue) {
        throw 'POS Pro esta ejecutandose. Cierrelo e intente la instalacion nuevamente.'
    }

    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null

    Write-Host "Compilacion seleccionada: $($build.Name)"
    Write-Host "Copiando archivos a $installPath ..."

    # /E incluye subcarpetas; no se eliminan archivos existentes para evitar
    # borrar configuraciones o datos que puedan estar en la instalacion.
    & robocopy.exe $sourcePath $installPath /E /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy no pudo copiar todos los archivos. Codigo: $LASTEXITCODE"
    }

    $installedExe = Join-Path $installPath 'pospro.exe'
    $installedIcon = Join-Path $installPath '_internal\app\share\pos-icon-01.ico'
    if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
        throw "No se encontro el ejecutable instalado: $installedExe"
    }
    if (-not (Test-Path -LiteralPath $installedIcon -PathType Leaf)) {
        throw "No se encontro el icono instalado: $installedIcon"
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $installedExe
    $shortcut.WorkingDirectory = $installPath
    $shortcut.IconLocation = "$installedIcon,0"
    $shortcut.Description = 'Effica'
    $shortcut.Save()

    Write-Host ''
    Write-Host 'Instalacion completada correctamente.' -ForegroundColor Green
    Write-Host "Ejecutable: $installedExe"
    Write-Host "Acceso directo: $shortcutPath"
}
catch {
    $errorLog = Join-Path $projectRoot 'install_pospro.log'
    $errorMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.Message)"
    Set-Content -LiteralPath $errorLog -Value $errorMessage -Encoding UTF8
    Write-Error "La instalacion fallo: $($_.Exception.Message)"
    exit 1
}

exit 0
