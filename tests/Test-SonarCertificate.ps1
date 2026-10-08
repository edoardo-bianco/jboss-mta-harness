#requires -Version 5.1
param([string]$KeytoolPath = (Get-Command keytool.exe -ErrorAction Stop).Source)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonarCertificate.psm1') -Force
$module = Get-Module HarnessSonarCertificate
$area = Join-Path $root ('.harness/tests/sonar-certificate-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($area)
$script:checks = 0
function Assert($condition, $message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
function Assert-Fails([scriptblock]$action, [string]$message) {
    $failed = $false
    try { & $action } catch { $failed = $true }
    Assert $failed $message
}
$oldUserHome = $env:SONAR_USER_HOME
$scannerJdk = Split-Path -Parent (Split-Path -Parent $KeytoolPath)
try {
    # Certificados sinteticos e PKCS12 reais, sem rede nem repositorios Windows/JDK.
    foreach ($name in @('first','second','expired')) {
        $extra = @()
        if ($name -eq 'expired') { $extra = @('-startdate','2020/01/01 00:00:00') }
        & $module { param($tool,$path,$label,$extra)
            $null = Invoke-SonarKeytool $tool (@('-genkeypair','-alias',$label,'-dname',"CN=$label.example",'-keyalg','RSA','-keysize','2048',
                '-validity','2','-keystore',"$path/$label.p12",'-storetype','PKCS12','-storepass','changeit','-keypass','changeit') + $extra)
            $null = Invoke-SonarKeytool $tool @('-exportcert','-alias',$label,'-keystore',"$path/$label.p12",'-storepass','changeit','-file',"$path/$label.cer")
        } $KeytoolPath $area $name $extra
    }
    & $module { param($path)
        $script:FixturePath = $path
        $script:CertificateName = 'first'
        $script:Answers = New-Object 'Collections.Generic.Queue[string]'
        $script:NativeKeytool = (Get-Command Invoke-SonarKeytool).ScriptBlock
        $script:FailImport = $false
        $script:CertificateReads = 0
        function script:Read-Host {
            param($Prompt)
            if (-not $script:Answers.Count) { throw 'Prompt inesperado no teste.' }
            $script:Answers.Dequeue()
        }
        function script:Invoke-SonarKeytool {
            param($Keytool,$Arguments)
            if ($Arguments -contains '-printcert') {
                $script:CertificateReads++
                $bytes = [IO.File]::ReadAllBytes((Join-Path $script:FixturePath ($script:CertificateName + '.cer')))
                return "Certificate[1]:`n-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($bytes))`n-----END CERTIFICATE-----"
            }
            if ($script:FailImport -and $Arguments -contains '-importcert') { throw 'Importacao simulada falhou.' }
            & $script:NativeKeytool $Keytool $Arguments
        }
    } $area
    $fingerprints = @{}
    foreach ($name in @('first','second')) {
        $fingerprints[$name] = & $module { param($file)
            $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 $file
            try { Get-SonarCertificateFingerprint $cert } finally { $cert.Dispose() }
        } (Join-Path $area ($name + '.cer'))
    }
    $env:SONAR_USER_HOME = Join-Path $area 'usuario com espaco & teste'
    $store = Join-Path $env:SONAR_USER_HOME 'ssl/truststore.p12'
    Initialize-HarnessSonarCertificate 'http://localhost:9000' $scannerJdk
    Assert (-not (Test-Path $env:SONAR_USER_HOME)) 'HTTP local criou truststore.'
    Assert-Fails { Initialize-HarnessSonarCertificate 'http://remote.example' $scannerJdk } 'HTTP remoto aceito.'
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://user:pass@sonar.example' $scannerJdk } 'URL com credenciais aceita.'
    & $module { $script:Answers.Enqueue('') }
    Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk
    Assert (-not (Test-Path $store)) 'Confianca do sistema importou certificado.'
    & $module { $script:Answers.Enqueue('q') }
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk } 'Cancelamento iniciou analise.'
    & $module { $script:Answers.Enqueue(('0' * 64)) }
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk -PrepareCertificate } 'Fingerprint diferente aceito.'
    Assert (-not (Test-Path $store)) 'Fingerprint diferente modificou truststore.'
    & $module { param($fingerprint) $script:Answers.Enqueue('c'); $script:Answers.Enqueue($fingerprint.ToLowerInvariant()) } $fingerprints.first
    Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk
    Assert (Test-Path $store) 'Primeiro preparo nao criou truststore.'
    $firstHash = (Get-FileHash $store -Algorithm SHA256).Hash
    $readCount = & $module { $script:CertificateReads }
    Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk
    Assert ((& $module { $script:CertificateReads }) -eq $readCount) 'Reuso consultou servidor ou repetiu prompt.'
    & $module { param($fingerprint) $script:Answers.Enqueue($fingerprint) } $fingerprints.first
    Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk -PrepareCertificate
    Assert ((Get-FileHash $store -Algorithm SHA256).Hash -ceq $firstHash) 'Reimportacao alterou truststore.'
    & $module { param($fingerprint)
        $script:CertificateName='second'; $script:FailImport=$true; $script:Answers.Enqueue($fingerprint)
    } $fingerprints.second
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://other.example' $scannerJdk -PrepareCertificate } 'Falha keytool ignorada.'
    Assert ((Get-FileHash $store -Algorithm SHA256).Hash -ceq $firstHash) 'Falha keytool danificou truststore existente.'
    & $module { param($fingerprint) $script:FailImport=$false; $script:Answers.Enqueue($fingerprint) } $fingerprints.second
    Initialize-HarnessSonarCertificate 'https://other.example' $scannerJdk -PrepareCertificate
    $pem = & $module { param($tool,$file) Invoke-SonarKeytool $tool @('-list','-rfc','-keystore',$file,'-storetype','PKCS12','-storepass','changeit') } $KeytoolPath $store
    Assert ([regex]::Matches($pem,'-----BEGIN CERTIFICATE-----').Count -eq 2) 'Novo servidor perdeu certificado anterior.'
    $secondHash = (Get-FileHash $store -Algorithm SHA256).Hash
    & $module { $script:Answers.Enqueue('') }
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://other.example' $scannerJdk -PrepareCertificate } 'Confirmacao vazia aceita.'
    Assert ((Get-FileHash $store -Algorithm SHA256).Hash -ceq $secondHash) 'Cancelamento alterou truststore existente.'
    & $module { $script:CertificateName='expired' }
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://expired.example' $scannerJdk -PrepareCertificate } 'Certificado expirado aceito.'
    Assert ((Get-FileHash $store -Algorithm SHA256).Hash -ceq $secondHash) 'Certificado expirado alterou truststore.'
    Assert (@(Get-ChildItem (Split-Path $store) -Force -Filter '.sonar-cert-*').Count -eq 0) 'Staging temporario ficou no perfil.'
    $env:SONAR_USER_HOME = 'relative-path'
    Assert-Fails { Initialize-HarnessSonarCertificate 'https://sonar.example' $scannerJdk } 'SONAR_USER_HOME relativo aceito.'
    Assert ((& $module { $script:Answers.Count }) -eq 0) 'Teste deixou respostas nao consumidas.'
    Write-Host "PASS sonar-certificate: $script:checks verificacoes; PS $($PSVersionTable.PSVersion); keytool real, sem rede."
} finally { $env:SONAR_USER_HOME = $oldUserHome }
