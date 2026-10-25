#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [string]$EditorPath,[switch]$NoOpen
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget -SkipMigrationInitialization
    if (-not $context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target.' }
    $project=Get-HarnessProjectStorage $root (Join-Path $context.Active.path 'pom.xml')
    $contract=Join-Path $root '.github/prompts/criar-revisar-issue.prompt.md'
    $template=[IO.File]::ReadAllText($contract)
    $pattern='(?s)\A---\r?\n.*?\r?\n---(?:\r?\n|$)'
    $header=[regex]::Match($template,$pattern)
    if (-not $header.Success) { throw 'Prompt de contrato sem cabecalho valido.' }
    $relative='atual/planejamento/criar-revisar-issue.prompt.md'
    $path=Join-Path $project.Folder $relative
    $lease=Enter-HarnessProjectAccess $project -ForOperation
    try {
        $old=Read-HarnessProjectFiles $project @('migracao.md',$relative)
        if (-not $old['migracao.md']) { throw 'Registro ausente; execute Workspace: atualizar indice dos projetos.' }
        $null=Get-HarnessMigrationCounts $old['migracao.md']
        $body="# Criar ou revisar issue`n`n## Observacoes do desenvolvedor`n`nUse o chat para informar o problema ou ID e as evidencias. Notas escritas aqui sao preservadas.`n"
        if ($null -ne $old[$relative]) {
            $previous=[regex]::Match($old[$relative],$pattern)
            if (-not $previous.Success) { throw 'Prompt existente sem cabecalho valido; preserve/revise o arquivo antes de preparar novamente.' }
            $body=$old[$relative].Substring($previous.Length).TrimStart("`r","`n")
        }
        $selection=[ordered]@{
            Project=$project.Name;Pom=$project.Pom;Source=$project.Source;HarnessRoot=$root
            MigrationPath=$project.MigrationPath;IndexPath=$project.IndexPath;EvidencePath=$project.EvidencePath
            ConfigPath=$context.ConfigPath;WorkspacePath=$context.WorkspacePath
        } | ConvertTo-Json -Depth 5
        $lines=@(
            'Ao executar este prompt, leia e execute o contrato completo: '+(Get-HarnessSourceLink $path $contract 'Criar ou revisar issue')+'.'
            'Use a selecao abaixo; nao pergunte novamente o projeto. Recupere problema/ID/evidencias do chat atual e pergunte somente o essencial ausente.'
            'Aproveite saidas de ferramentas e logs ja acessiveis na sessao; outra conversa exige trecho ou arquivo acessivel. Nao presuma acesso a historico de outros chats.'
            'Este arquivo prepara o pedido; somente sua execucao pelo agente investiga e publica a ficha.'
            ''
            (Get-HarnessSourceLink $path $project.IndexPath 'Indice do projeto')
            (Get-HarnessSourceLink $path $project.MigrationPath 'Registro de migracao')
            ''
            '```json'
            $selection
            '```'
        )
        $text=$header.Value.TrimEnd()+"`n`n"+(Set-ProjectManagedBlock $body 'issue:preparo' ($lines -join "`n"))
        if ($text -cne $old[$relative]) { Publish-HarnessProjectFiles $project @{$relative=$text} $old }
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
    Write-Host "Prompt preparado: $path"
    Write-Host 'No Copilot Local, use Executar Prompt no chat atual para aproveitar as evidencias da conversa. O prompt seleciona devsquad quando instalado.'
    Write-Host 'Sem devsquad, selecione Agent e peca: Execute o prompt deste arquivo, usando as evidencias desta conversa.'
    Write-Host 'No Codex ou Claude Code, peca ao agente principal: Execute o prompt deste arquivo, usando as evidencias desta conversa. Informe o caminho acima.'
    Write-Host 'Informe problema/ID ou log no chat; o agente perguntara apenas o que faltar. Preparar nao cadastra issue nem executa corretiva.'
    if (-not $NoOpen -and $EditorPath) {
        try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $path -Root $root }
        catch { Write-Warning ('Prompt disponivel; abra o caminho acima. '+$_.Exception.Message) }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao preparar issue: '+$_.Exception.Message) -ForegroundColor Red
    exit 1
}
