Import-Module (Join-Path $PSScriptRoot 'HarnessMtaLocation.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessMtaExternalPublication.ps1')

function Invoke-MtaAnalysis {
    param($Context)
    if (-not $Context.Active) { throw 'Escolha o projeto Maven.' }
    $reference=Get-HarnessProjectReference $Context.Root (Join-Path $Context.Active.path 'pom.xml')
    $location=Get-HarnessMtaExternalLocation $Context $reference
    $rules=Get-MtaRequirements $Context
    $project=Initialize-HarnessProjectStorage $Context.Root (Join-Path $Context.Active.path 'pom.xml')
    $lease=Enter-HarnessProjectAccess $project -ForOperation
    try {
    $documents=Read-HarnessProjectFiles $project @('projeto.json')
    $association=Get-HarnessMtaExternalAssociationText $project $location $documents['projeto.json']
    $temporary=Get-HarnessProjectTemporary $project 'mta'
    $previous=@{}; $pushed=$false; $writes=@{}; $stage=$null
    $result=[ordered]@{Project=$project.Name;Source=$project.Source;Status='FAILED';ExitCode=$null;Error=$null;Version=$null;
        SourceUnchanged=$null;InputUnchanged=$null;RulesUnchanged=$null;
        ReportPath=$null;
        LogPath=(Join-Path $project.Folder 'atual/diagnosticos/mta-console.log');ResultPath=(Join-Path $project.Folder 'atual/operacao.json')}
    try {
        Remove-HarnessProjectTemporary $project 'mta'
        $stage=New-MtaExternalStage $location
        $inputPath=Join-Path $temporary 'entrada'; $outputPath=$stage.Output; $rulePath=Join-Path $temporary 'regras'
        $sourceFiles=@(Get-HarnessFiles $project.Source); $ruleFiles=@(Get-HarnessFiles $rules -Rules)
        if (-not $ruleFiles.Count) { throw 'Nenhuma regra YAML encontrada.' }
        # The analyzer may create IDE metadata. Isolate that in a disposable
        # input copy; never keep it as a snapshot or navigation dependency.
        Copy-HarnessFiles $project.Source $inputPath $sourceFiles
        Copy-HarnessFiles $rules $rulePath $ruleFiles
        Set-HarnessProjectOperation $project 'mta' 'RUNNING' -LogPath (Join-Path $temporary 'console.log')
        $tool=$Context.Config.tools
        foreach ($name in @('JAVA_HOME','PATH','JVM_MAX_MEM','SONAR_TOKEN','MAVEN_HOME','M2_HOME','JAVA_OPTS','MAVEN_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','KANTRA_DIR')) {
            $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
            [Environment]::SetEnvironmentVariable($name,$null,'Process')
        }
        $env:KANTRA_DIR=Split-Path -Parent $tool.mtaExecutable; $env:JAVA_HOME=$tool.mtaJdkHome
        $env:MAVEN_HOME=$tool.mavenHome; $env:M2_HOME=$tool.mavenHome; $env:JVM_MAX_MEM='2g'
        $env:PATH=(Join-Path $tool.mtaJdkHome 'bin')+';'+(Join-Path $tool.mavenHome 'bin')+';'+$env:KANTRA_DIR+';'+$previous.PATH
        Push-Location -LiteralPath $temporary; $pushed=$true
        Write-Host "Projeto: $($project.Name) | Log em andamento: $(Join-Path $temporary 'console.log')"
        $arguments=@('analyze','--input',$inputPath,'--output',$outputPath,'--run-local','--mode',$Context.Config.mta.mode,'--enable-default-rulesets=false','--rules',$rulePath)
        foreach ($target in $Context.Config.mta.targets) { $arguments+=@('--target',$target) }
        if ($tool.mavenSettingsPath) { $arguments+=@('--maven-settings',$tool.mavenSettingsPath) }
        $version=Invoke-HarnessMtaTool $tool.mtaExecutable @('version'); $result.Version=$version.Output
        if ($version.ExitCode -ne 0) { $result.ExitCode=$version.ExitCode; throw 'Falha ao consultar versao MTA.' }
        $execution=Invoke-HarnessMtaTool $tool.mtaExecutable $arguments (Join-Path $temporary 'console.log')
        $result.ExitCode=$execution.ExitCode
        if ($execution.ExitCode -ne 0) { throw "MTA terminou com codigo $($execution.ExitCode); diagnostico anterior preservado." }
        $inputAfter=@(Get-HarnessFiles $inputPath); $byPath=@{}
        foreach ($file in $inputAfter) { $byPath[$file.path]=$file.sha256 }
        $result.InputUnchanged=@($sourceFiles | Where-Object { $byPath[$_.path] -cne $_.sha256 }).Count -eq 0
        $known=@('.classpath','.project','.settings/org.eclipse.core.resources.prefs','.settings/org.eclipse.jdt.apt.core.prefs','.settings/org.eclipse.jdt.core.prefs','.settings/org.eclipse.m2e.core.prefs')
        $originalPaths=@($sourceFiles | ForEach-Object path)
        if (@($inputAfter | Where-Object { $_.path -notin $originalPaths -and $_.path -notin $known }).Count) { throw 'MTA acrescentou arquivo inesperado a entrada temporaria; confira antes de publicar.' }
        $result.SourceUnchanged=((@(Get-HarnessFiles $project.Source) | ConvertTo-Json -Compress) -ceq ($sourceFiles | ConvertTo-Json -Compress))
        $result.RulesUnchanged=((@(Get-HarnessFiles $rulePath -Rules) | ConvertTo-Json -Compress) -ceq ($ruleFiles | ConvertTo-Json -Compress))
        if (-not $result.InputUnchanged -or -not $result.SourceUnchanged -or -not $result.RulesUnchanged) { throw 'Fontes ou regras mudaram durante analise; diagnostico anterior preservado.' }
        $mta=Read-HarnessMtaDirectory $project $outputPath
        $result.ReportPath=Publish-MtaExternalReport $project $location $stage $mta $documents['projeto.json'] $association
        $result.Status='SUCCEEDED'
    } catch { $result.Error=$_.Exception.Message; $writes=@{} }
    finally {
        if ($pushed) { Pop-Location }
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
            $console=Join-Path $temporary 'console.log'; $internal=Join-Path $temporary '.metadata/.log'
            $writes['atual/diagnosticos/mta-console.log']=if (Test-Path -LiteralPath $console -PathType Leaf) { [IO.File]::ReadAllText($console) } else { [string]$result.Error }
            if (Test-Path -LiteralPath $internal -PathType Leaf) {
                $writes['atual/diagnosticos/mta-interno.log']=[IO.File]::ReadAllBytes($internal)
            } elseif (Test-Path -LiteralPath (Join-Path $project.Folder 'atual/diagnosticos/mta-interno.log') -PathType Leaf) {
                $writes['atual/diagnosticos/mta-interno.log']=$null
            }
            try {
                Set-HarnessProjectOperation $project 'mta' $result.Status -ErrorMessage $result.Error -LogPath $result.LogPath -Files $writes
            } finally {
                try { Remove-HarnessProjectTemporary $project 'mta' }
                finally { if ($stage) { Remove-MtaExternalStage $stage } }
            }
    }
    [pscustomobject]$result
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}

function Get-LastMtaReport {
    param($Context)
    if (-not $Context.Active) { throw 'Escolha o projeto Maven.' }
    $project=Get-HarnessProjectStorage $Context.Root (Join-Path $Context.Active.path 'pom.xml')
    $mta=Read-HarnessProjectMta $project
    foreach ($warning in $mta.Diagnostics) { Write-Warning $warning }
    $documents=Read-HarnessProjectFiles $project @('atual/operacao.json')
    if ($documents['atual/operacao.json']) {
        $operations=ConvertFrom-Json $documents['atual/operacao.json']
        if ($operations.PSObject.Properties['mta'] -and $operations.mta.Status -ne 'SUCCEEDED') { Write-Warning ('Ultima tentativa MTA: '+$operations.mta.Status+'. '+$operations.mta.Error+'. Exibindo ultimo diagnostico completo: '+$mta.ReportPath) }
    }
    $mta.ReportPath
}
