#requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSCommandPath
$distRoot = Join-Path $projectRoot 'dist'
$buildScript = Join-Path $projectRoot 'build_pospro.bat'
$installerRoot = Join-Path $projectRoot 'installer'
$wixSource = Join-Path $installerRoot 'Effica.wxs'
$msiPath = Join-Path $projectRoot 'dist\Effica.msi'
$wix = 'C:\Program Files\WiX Toolset v6.0\bin\wix.exe'

function Escape-Xml([string]$value) {
    return [System.Security.SecurityElement]::Escape($value)
}

function New-BrandBitmaps {
    param(
        [Parameter(Mandatory)] [string]$LogoPath,
        [Parameter(Mandatory)] [string]$BannerPath,
        [Parameter(Mandatory)] [string]$DialogPath
    )

    Add-Type -AssemblyName System.Drawing
    $logo = [System.Drawing.Image]::FromFile($LogoPath)
    try {
        $font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
        $smallFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Regular)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(35, 48, 68))
        $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(95, 105, 120))
        $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $quality = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $banner = New-Object System.Drawing.Bitmap(493, 58)
        $graphics = [System.Drawing.Graphics]::FromImage($banner)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = $quality
            # WiX coloca el titulo de cada pantalla en el lado izquierdo del
            # banner; el logo se mantiene a la derecha para evitar traslapes.
            $graphics.DrawImage($logo, (New-Object System.Drawing.Rectangle(438, 8, 42, 42)))
            $banner.Save($BannerPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $graphics.Dispose(); $banner.Dispose() }

        $dialog = New-Object System.Drawing.Bitmap(493, 312)
        $graphics = [System.Drawing.Graphics]::FromImage($dialog)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = $quality
            # El asistente de WiX dibuja el título y el texto en el centro.
            # El logo queda abajo a la izquierda para no tapar esos textos.
            $graphics.DrawImage($logo, (New-Object System.Drawing.Rectangle(24, 207, 82, 82)))
            $dialog.Save($DialogPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $graphics.Dispose(); $dialog.Dispose() }

        $font.Dispose(); $smallFont.Dispose(); $brush.Dispose(); $mutedBrush.Dispose(); $whiteBrush.Dispose()
    }
    finally { $logo.Dispose() }
}

function New-DirectoryXml {
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo]$Directory,
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [ref]$NextId
    )

    $directoryId = 'D{0}' -f $NextId.Value
    $NextId.Value++
    $name = Escape-Xml $Directory.Name
    $lines = [System.Collections.Generic.List[string]]::new()
    $isRoot = $RelativePath -eq '.'
    if (-not $isRoot) {
        $lines.Add("<Directory Id=`"$directoryId`" Name=`"$name`">")
    }

    foreach ($file in ($Directory.EnumerateFiles() | Sort-Object Name)) {
        $fileId = 'F{0}' -f $NextId.Value
        $componentId = 'C{0}' -f $NextId.Value
        $componentGuid = [Guid]::NewGuid().ToString().ToUpperInvariant()
        $NextId.Value++
        $sourceRelativePath = if ($isRoot) { $file.Name } else { $RelativePath + '\' + $file.Name }
        $filePath = Escape-Xml (Join-Path '$(var.SourceDir)' $sourceRelativePath)
        $script:ComponentIds.Add($componentId)
        $lines.Add("<Component Id=`"$componentId`" Guid=`"$componentGuid`"><File Id=`"$fileId`" Source=`"$filePath`" KeyPath=`"yes`" /></Component>")
    }

    foreach ($child in ($Directory.EnumerateDirectories() | Sort-Object Name)) {
        $childRelativePath = if ($isRoot) { $child.Name } else { $RelativePath + '\' + $child.Name }
        $childXml = New-DirectoryXml -Directory $child -RelativePath $childRelativePath -NextId $NextId
        foreach ($line in $childXml) {
            $lines.Add($line)
        }
    }

    if (-not $isRoot) {
        $lines.Add('</Directory>')
    }
    return $lines
}

try {
    if (-not (Test-Path -LiteralPath $wix -PathType Leaf)) {
        throw "No se encontro WiX Toolset en $wix"
    }
    if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
        throw "No se encontro el script de compilacion: $buildScript"
    }

    if (-not $SkipBuild) {
        Write-Host 'Generando la compilacion de Effica...'
        & cmd.exe /c "`"$buildScript`""
        if ($LASTEXITCODE -ne 0) {
            throw "La compilacion fallo. Codigo: $LASTEXITCODE"
        }
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
    $iconPath = Join-Path $sourcePath '_internal\app\share\pos-icon-01.ico'
    $logoPath = Join-Path $sourcePath '_internal\app\share\pos-icon-01.png'
    if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
        throw "La compilacion no contiene el icono requerido: $iconPath"
    }
    if (-not (Test-Path -LiteralPath $logoPath -PathType Leaf)) {
        throw "La compilacion no contiene el logo requerido: $logoPath"
    }

    New-Item -ItemType Directory -Path $installerRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $msiPath) -Force | Out-Null
    $bannerPath = Join-Path $installerRoot 'EfficaBanner.png'
    $dialogPath = Join-Path $installerRoot 'EfficaDialog.png'
    $licensePath = Join-Path $installerRoot 'EfficaTerms.rtf'
    if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
        throw "No se encontro el documento de terminos: $licensePath"
    }
    New-BrandBitmaps -LogoPath $logoPath -BannerPath $bannerPath -DialogPath $dialogPath

    $nextId = [ref]1
    $script:ComponentIds = [System.Collections.Generic.List[string]]::new()
    $directoryXml = New-DirectoryXml -Directory (Get-Item -LiteralPath $sourcePath) -RelativePath '.' -NextId $nextId
    $now = Get-Date
    # MSI allows major/minor values below 256 and a build value below 65536.
    # Encode year, month, day and time while staying inside those limits.
    $buildNumber = ($now.DayOfYear * 144) + ($now.Hour * 6) + [math]::Floor($now.Minute / 10)
    $version = '{0}.{1}.{2}' -f ($now.Year % 100), $now.Month, $buildNumber
    $wixLines = [System.Collections.Generic.List[string]]::new()
    $wixLines.Add('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs" xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">')
    $wixLines.Add("<Package Name=`"Effica`" Manufacturer=`"Effica`" Version=`"$version`" UpgradeCode=`"7B7D0B77-8C91-46BA-9F40-2B17EA0FD4A7`" Scope=`"perMachine`">")
    $wixLines.Add('<MajorUpgrade AllowSameVersionUpgrades="yes" DowngradeErrorMessage="Ya existe una version mas reciente de Effica instalada." />')
    $wixLines.Add('<MediaTemplate EmbedCab="yes" CompressionLevel="high" />')
    $wixLines.Add('<Icon Id="EfficaIcon" SourceFile="$(var.IconSource)" />')
    $wixLines.Add('<Property Id="ARPPRODUCTICON" Value="EfficaIcon" />')
    $wixLines.Add('<WixVariable Id="WixUIBannerBmp" Value="$(var.BannerSource)" />')
    $wixLines.Add('<WixVariable Id="WixUIDialogBmp" Value="$(var.DialogSource)" />')
    $wixLines.Add('<WixVariable Id="WixUILicenseRtf" Value="$(var.LicenseSource)" />')
    $wixLines.Add('<StandardDirectory Id="TARGETDIR"><Directory Id="APPSFOLDER" Name="Apps"><Directory Id="INSTALLFOLDER" Name="Effica">')
    foreach ($line in $directoryXml) { $wixLines.Add($line) }
    $wixLines.Add('</Directory></Directory></StandardDirectory>')
    $wixLines.Add('<Feature Id="MainFeature" Title="Effica" Level="1">')
    foreach ($componentId in $script:ComponentIds) {
        $wixLines.Add("<ComponentRef Id=`"$componentId`" />")
    }
    $wixLines.Add('<ComponentRef Id="EfficaDesktopShortcut" />')
    $wixLines.Add('<ComponentRef Id="EfficaStartMenuShortcut" />')
    $wixLines.Add('</Feature>')
    $wixLines.Add('<Property Id="CREATE_START_MENU" Value="0" />')
    $wixLines.Add('<UI>')
    $wixLines.Add('<Dialog Id="StartMenuDlg" Width="370" Height="270" Title="[ProductName]">')
    $wixLines.Add('<Control Id="Title" Type="Text" X="15" Y="15" Width="340" Height="30" Transparent="yes" NoPrefix="yes" Text="Acceso directo en el menu Inicio" />')
    $wixLines.Add('<Control Id="Description" Type="Text" X="15" Y="55" Width="340" Height="35" Transparent="yes" NoPrefix="yes" Text="¿Desea crear un acceso directo de Effica en la pantalla de inicio?" />')
    $wixLines.Add('<Control Id="StartMenuCheckBox" Type="CheckBox" X="25" Y="110" Width="320" Height="18" Property="CREATE_START_MENU" CheckBoxValue="1" Text="Crear acceso directo en el menu Inicio" />')
    $wixLines.Add('<Control Id="Back" Type="PushButton" X="220" Y="243" Width="56" Height="17" Text="Atras"><Publish Event="NewDialog" Value="InstallDirDlg" /></Control>')
    $wixLines.Add('<Control Id="Next" Type="PushButton" X="280" Y="243" Width="56" Height="17" Default="yes" Text="Siguiente"><Publish Event="NewDialog" Value="VerifyReadyDlg" /></Control>')
    $wixLines.Add('<Control Id="Cancel" Type="PushButton" X="320" Y="243" Width="56" Height="17" Cancel="yes" Text="Cancelar"><Publish Event="SpawnDialog" Value="CancelDlg" /></Control>')
    $wixLines.Add('</Dialog>')
    $wixLines.Add('<Publish Dialog="InstallDirDlg" Control="Next" Event="NewDialog" Value="StartMenuDlg" Order="3" Condition="1" />')
    $wixLines.Add('<Publish Dialog="LicenseAgreementDlg" Control="Next" Event="NewDialog" Value="StartMenuDlg" Order="3" Condition="1" />')
    $wixLines.Add('</UI>')
    $wixLines.Add('<ui:WixUI Id="WixUI_InstallDir" InstallDirectory="INSTALLFOLDER" />')
    $shortcutGuid = [Guid]::NewGuid().ToString().ToUpperInvariant()
    $wixLines.Add("<StandardDirectory Id=`"DesktopFolder`"><Component Id=`"EfficaDesktopShortcut`" Guid=`"$shortcutGuid`">")
    $wixLines.Add('<Shortcut Id="EfficaShortcut" Name="Effica" Target="[INSTALLFOLDER]pospro.exe" WorkingDirectory="INSTALLFOLDER" Icon="EfficaIcon" />')
    $wixLines.Add('<CreateFolder />')
    $wixLines.Add('<RemoveFolder Id="RemoveEfficaShortcutFolder" On="uninstall" />')
    $wixLines.Add('</Component></StandardDirectory>')
    $startMenuGuid = [Guid]::NewGuid().ToString().ToUpperInvariant()
    $wixLines.Add("<StandardDirectory Id=`"ProgramMenuFolder`"><Directory Id=`"EFFICA_PROGRAMMENU`" Name=`"Effica`"><Component Id=`"EfficaStartMenuShortcut`" Guid=`"$startMenuGuid`" Condition=`"CREATE_START_MENU`">")
    $wixLines.Add('<Shortcut Id="EfficaStartMenuShortcut" Name="Effica" Target="[INSTALLFOLDER]pospro.exe" WorkingDirectory="INSTALLFOLDER" Icon="EfficaIcon" />')
    $wixLines.Add('<CreateFolder />')
    $wixLines.Add('<RemoveFolder Id="RemoveEfficaStartMenuFolder" On="uninstall" />')
    $wixLines.Add('</Component></Directory></StandardDirectory>')
    $wixLines.Add('</Package></Wix>')

    $wixText = $wixLines -join [Environment]::NewLine
    Set-Content -LiteralPath $wixSource -Value $wixText -Encoding UTF8

    Write-Host "Generando MSI desde $($build.Name)..."
    & $wix build -arch x64 -culture es-ES -ext WixToolset.UI.wixext -d "SourceDir=$sourcePath" -d "IconSource=$iconPath" -d "BannerSource=$bannerPath" -d "DialogSource=$dialogPath" -d "LicenseSource=$licensePath" -o $msiPath $wixSource
    if ($LASTEXITCODE -ne 0) {
        throw "WiX no pudo generar el MSI. Codigo: $LASTEXITCODE"
    }

    Write-Host "MSI generado correctamente: $msiPath" -ForegroundColor Green
}
catch {
    $errorLog = Join-Path $projectRoot 'installer\build_effica_msi.log'
    Set-Content -LiteralPath $errorLog -Value ("[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.Message)") -Encoding UTF8
    Write-Error "La generacion del MSI fallo: $($_.Exception.Message)"
    exit 1
}

exit 0
