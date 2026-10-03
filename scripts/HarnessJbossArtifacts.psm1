#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function Get-HarnessJbossArtifacts {
    param([string]$ProjectPath)
    $pending=New-Object Collections.Queue
    $pending.Enqueue((Resolve-HarnessPath $ProjectPath $ProjectPath))
    $seen=@{}; $artifacts=@()
    while ($pending.Count) {
        $folder=$pending.Dequeue()
        if ($seen.ContainsKey($folder)) { continue }
        $seen[$folder]=$true
        $pom=Resolve-HarnessPath (Join-Path $folder 'pom.xml') $folder
        if (-not (Test-Path -LiteralPath $pom -PathType Leaf)) {
            Write-Warning "Modulo sem pom.xml: $folder. Use caminho manual se necessario."
            continue
        }
        $target=Resolve-HarnessPath (Join-Path $folder 'target') $folder
        if (Test-Path -LiteralPath $target -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $target -File) {
                if ($file.Extension -notin @('.war','.ear')) { continue }
                $path=Resolve-HarnessPath $file.FullName $folder
                $artifacts+=[pscustomobject]@{ModulePath=$folder;ArtifactPath=$path}
            }
        }
        $reader=$null
        try {
            $settings=New-Object Xml.XmlReaderSettings
            $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit
            $settings.XmlResolver=$null
            $reader=[Xml.XmlReader]::Create($pom,$settings)
            $xml=New-Object Xml.XmlDocument
            $xml.XmlResolver=$null
            $xml.Load($reader)
            foreach ($node in $xml.SelectNodes("/*[local-name()='project']/*[local-name()='modules']/*[local-name()='module']")) {
                $module=$node.InnerText.Trim()
                if (-not $module -or $module.Contains('${')) {
                    Write-Warning "Modulo Maven nao resolvido em ${pom}: $module. Use caminho manual se necessario."
                    continue
                }
                $pending.Enqueue((Resolve-HarnessPath $module $folder))
            }
        } catch { Write-Warning "Nao foi possivel descobrir todos os modulos de ${pom}: $($_.Exception.Message). Use caminho manual se necessario." }
        finally { if ($reader) { $reader.Dispose() } }
    }
    $artifacts | Sort-Object ArtifactPath -Unique
}

function Select-HarnessJbossArtifact {
    param([string]$ProjectPath)
    $candidates=@(Get-HarnessJbossArtifacts $ProjectPath)
    if ($candidates.Count) {
        Write-Host 'WAR/EAR encontrados em target do projeto e dos modulos Maven:'
        for ($i=0;$i -lt $candidates.Count;$i++) {
            Write-Host ("{0}. {1}" -f ($i+1),$candidates[$i].ArtifactPath)
        }
        $prompt=if ($candidates.Count -eq 1) {'Artefato (Enter usa 1; m informa caminho; q cancela)'} else {'Numero do artefato (m informa caminho; Enter/q cancela)'}
        $choice=Read-Host $prompt
        if ($candidates.Count -eq 1 -and [string]::IsNullOrWhiteSpace($choice)) { return $candidates[0].ArtifactPath }
        if ($choice -ne 'm') {
            $number=0
            if (-not [int]::TryParse($choice,[ref]$number) -or $number -lt 1 -or $number -gt $candidates.Count) { throw 'Selecao cancelada ou invalida.' }
            return $candidates[$number-1].ArtifactPath
        }
    } else {
        Write-Host 'Nenhum WAR/EAR encontrado em target. Execute Aplicacao: build Maven (Java 8), fase package/verify/install, ou informe uma saida personalizada.'
    }
    $path=Read-Host 'Caminho do WAR/EAR ja construido (Enter/q cancela)'
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq 'q') { throw 'Selecao cancelada.' }
    return $path
}

Export-ModuleMember -Function Get-HarnessJbossArtifacts, Select-HarnessJbossArtifact
