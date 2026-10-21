#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Read-Frontmatter([string]$Path) {
    $text=[IO.File]::ReadAllText($Path).Replace("`r`n","`n")
    $match=[regex]::Match($text,'^---\n(.*?)\n---\n(.*)$','Singleline')
    Assert $match.Success "Frontmatter ausente: $Path"
    $fields=@{}
    foreach ($line in $match.Groups[1].Value.Split("`n")) {
        $pair=[regex]::Match($line,'^([A-Za-z]+):\s*(.*)$')
        if ($pair.Success) { $fields[$pair.Groups[1].Value]=$pair.Groups[2].Value.Trim() }
    }
    [pscustomobject]@{Fields=$fields;Body=$match.Groups[2].Value}
}
$readOnly=@('Read','Grep','Glob','mcp__harnessIssues__auditar_base','mcp__harnessIssues__listar_issues','mcp__harnessIssues__obter_issue')
$copilot=@(Get-ChildItem (Join-Path $root '.github/agents') -Filter '*.agent.md' | ForEach-Object { $_.Name -replace '\.agent\.md$','' })
$codex=@(Get-ChildItem (Join-Path $root '.codex/agents') -Filter '*.toml' | ForEach-Object { $_.BaseName })
$claude=@(Get-ChildItem (Join-Path $root '.claude/agents') -Filter '*.md' | ForEach-Object { $_.BaseName })
Assert (($copilot | Sort-Object) -join ',' -eq ($claude | Sort-Object) -join ',') 'Claude Code deve ter os mesmos helpers do Copilot.'
Assert (($codex | Sort-Object) -join ',' -eq ($claude | Sort-Object) -join ',') 'Claude Code deve ter os mesmos helpers do Codex.'
$roles=[IO.File]::ReadAllText((Join-Path $root '.agents/skills/orientar-migracao/references/papeis.md'))
$specialists=@($claude | Where-Object { $_ -ne 'migracao_helper' })
foreach ($name in $claude) {
    $agent=Read-Frontmatter (Join-Path $root ".claude/agents/$name.md")
    Assert ($agent.Fields.name -ceq $name -and $agent.Fields.description) "Nome/descricao invalidos: $name"
    $copilotDescription=(Read-Frontmatter (Join-Path $root ".github/agents/$name.agent.md")).Fields.description
    Assert ($agent.Fields.description -ceq $copilotDescription) "Descricao divergente do Copilot: $name"
    Assert ($roles -match ('(?m)^## '+[regex]::Escape($name)+'\s*$')) "Papel ausente em papeis.md: $name"
    Assert ($agent.Body.Contains('.agents/skills/orientar-migracao/SKILL.md') -and $agent.Body.Contains("secao $name em .agents/skills/orientar-migracao/references/papeis.md")) "Helper deve apontar para a skill e para seu papel: $name"
    Assert ($agent.Body.Contains('Nao execute tarefas nem altere arquivos.') -and $agent.Body.Contains('Claude Code')) "Helper deve declarar cliente e papel leitor: $name"
    $tools=@([regex]::Matches($agent.Fields.tools,'Agent\([^)]*\)|[^,\s][^,]*') | ForEach-Object { $_.Value.Trim() })
    foreach ($tool in $tools) {
        if ($tool -like 'Agent*') {
            Assert ($name -eq 'migracao_helper') "Somente o condutor pode delegar: $name"
            $allowed=@([regex]::Match($tool,'^Agent\((.*)\)$').Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            Assert (($allowed | Sort-Object) -join ',' -eq ($specialists | Sort-Object) -join ',') 'Condutor deve delegar somente aos cinco helpers.'
        } else {
            Assert ($tool -in $readOnly) "Ferramenta fora do perfil leitor em ${name}: $tool"
        }
    }
    if ($name -ne 'migracao_helper') { Assert ($agent.Body.Contains('Nao delegue.')) "Especialista nao deve subdelegar: $name" }
}
# Os adaptadores compartilham o papel, mas cada cliente restringe capacidades
# em campos diferentes. Validar esses campos evita aceitar apenas paridade de nomes.
$copilotReadOnly=@('read/readFile','search/listDirectory','search/fileSearch','search/textSearch','search/codebase','search/usages','harnessissues/auditar_base','harnessissues/listar_issues','harnessissues/obter_issue')
foreach ($name in $copilot) {
    $agent=Read-Frontmatter (Join-Path $root ".github/agents/$name.agent.md")
    Assert ($agent.Fields.name -ceq $name) "Identidade Copilot divergente: $name"
    $tools=ConvertFrom-Json $agent.Fields.tools
    Assert ($tools.Count -gt 0 -and 'read/readFile' -in $tools) "Copilot exige ferramentas explicitas de leitura: $name"
    foreach ($tool in $tools) {
        Assert ($tool -in $copilotReadOnly -or ($tool -ceq 'agent' -and $name -ceq 'migracao_helper')) "Capacidade fora do perfil leitor Copilot em ${name}: $tool"
    }
    Assert ($agent.Body.Contains('../../.agents/skills/orientar-migracao/SKILL.md') -and $agent.Body.Contains("../../.agents/skills/orientar-migracao/references/papeis.md#$name")) "Copilot deve apontar para a skill e seu papel: $name"
    if ($name -eq 'migracao_helper') {
        $allowed=ConvertFrom-Json $agent.Fields.agents
        $expected=@($specialists)+@('devsquad.plan')
        Assert ('agent' -in $tools -and (($allowed | Sort-Object) -join ',') -ceq (($expected | Sort-Object) -join ',')) 'Copilot condutor deve limitar delegacao aos helpers e apoio opcional declarado.'
    } else {
        Assert (-not $agent.Fields.ContainsKey('agents') -and $agent.Body.Contains('Nao delegue.')) "Copilot especialista nao deve habilitar subdelegacao: $name"
    }
}
foreach ($name in $codex) {
    $text=[IO.File]::ReadAllText((Join-Path $root ".codex/agents/$name.toml")).Replace("`r`n","`n")
    # Leitura delimitada do formato TOML usado nestes perfis; nao e parser TOML geral.
    $parts=[regex]::Match($text,'\A(?<settings>.*?)developer_instructions\s*=\s*"""(?<body>.*?)"""(?<tail>.*)\z','Singleline')
    Assert $parts.Success "Perfil Codex exige instrucoes explicitas: $name"
    $settings=$parts.Groups['settings'].Value
    $body=$parts.Groups['body'].Value
    $tail=$parts.Groups['tail'].Value
    Assert ($settings -match ('(?m)^name\s*=\s*"'+[regex]::Escape($name)+'"\s*$')) "Identidade Codex divergente: $name"
    Assert ($settings -match '(?m)^sandbox_mode\s*=\s*"read-only"\s*$') "Codex exige sandbox somente leitura: $name"
    Assert ($body.Contains('.agents/skills/orientar-migracao/SKILL.md') -and $body.Contains("secao $name em .agents/skills/orientar-migracao/references/papeis.md")) "Codex deve apontar para a skill e seu papel: $name"
    Assert ($body.Contains('Nao execute tarefas nem altere arquivos.')) "Codex deve manter limite orientador: $name"
    if ($name -ne 'migracao_helper') {
        Assert ($tail -match '\A\s*\[agents\]\s*enabled\s*=\s*false\s*\z' -and $body.Contains('Nao delegue.')) "Codex especialista deve desabilitar subdelegacao: $name"
    }
}
$pointer=Read-Frontmatter (Join-Path $root '.claude/skills/orientar-migracao/SKILL.md')
$common=Read-Frontmatter (Join-Path $root '.agents/skills/orientar-migracao/SKILL.md')
Assert ($pointer.Fields.name -ceq 'orientar-migracao' -and $pointer.Fields.description -ceq $common.Fields.description) 'Ponteiro da skill deve repetir nome/descricao da skill comum.'
Assert ($pointer.Body.Contains('](../../../.agents/skills/orientar-migracao/SKILL.md)')) 'Ponteiro deve linkar a skill comum.'
Assert (Test-Path -LiteralPath (Join-Path $root '.claude/skills/orientar-migracao/../../../.agents/skills/orientar-migracao/SKILL.md')) 'Link do ponteiro nao resolve.'
Assert (-not ($pointer.Body -match '(?m)^## ')) 'Ponteiro nao deve definir regras proprias.'
$skill=[IO.File]::ReadAllText((Join-Path $root '.agents/skills/orientar-migracao/SKILL.md'))
Assert ($skill.Contains('Claude Code, ao Codex e ao GitHub Copilot') -and $skill.Contains('- Claude Code: destinatario e a conversa principal')) 'Skill comum deve orientar o encaminhamento no Claude Code.'
Write-Output 'PASS: adaptadores Claude Code, Copilot e Codex com identidade, perfil leitor, limites de delegacao e ponteiros da skill comum.'
