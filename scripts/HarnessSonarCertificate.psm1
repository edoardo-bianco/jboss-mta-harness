#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-SonarKeytool {
    param([string]$Keytool, [string[]]$Arguments)
    # Executavel direto, sem cmd.exe; nenhum token Sonar participa deste preparo.
    foreach ($value in @($Keytool) + $Arguments) {
        if ([string]::IsNullOrEmpty($value) -or $value -match '["\r\n]' -or $value.EndsWith('\')) { throw 'Argumento keytool invalido.' }
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = $Keytool
    $process.StartInfo.Arguments = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            $process.WaitForExit()
            throw 'keytool excedeu 30 segundos. Confira conexao direta e disponibilidade do servidor.'
        }
        $output = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw 'keytool falhou. Confira acesso ao servidor, arquivo e senha changeit do truststore; consulte o guia Sonar.'
        }
        $output
    } finally { $process.Dispose() }
}

function Get-SonarPresentedCertificate {
    param([string]$Keytool, [Uri]$Server)
    $endpoint = $Server.DnsSafeHost + ':' + $Server.Port
    if ($Server.HostNameType -eq [UriHostNameType]::IPv6) { $endpoint = '[' + $Server.DnsSafeHost.Trim('[',']') + ']:' + $Server.Port }
    $pem = Invoke-SonarKeytool $Keytool @('-printcert','-sslserver',$endpoint,'-rfc')
    $match = [regex]::Match($pem, '(?s)-----BEGIN CERTIFICATE-----\s*(?<der>[A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----')
    if (-not $match.Success) { throw 'O servidor nao forneceu um certificado publico legivel.' }
    # Primeiro certificado apresentado: certificado do servidor, sem chave privada.
    $bytes = [Convert]::FromBase64String($match.Groups['der'].Value)
    New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$bytes)
}

function Get-SonarCertificateFingerprint {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($Certificate.RawData)).Replace('-','') }
    finally { $sha.Dispose() }
}

function Get-SonarDefaultTruststore {
    $base = $env:SONAR_USER_HOME
    if (-not $base) { $base = Join-Path $env:USERPROFILE '.sonar' }
    if (-not [IO.Path]::IsPathRooted($base)) { throw 'SONAR_USER_HOME deve ser um caminho absoluto.' }
    Join-Path ([IO.Path]::GetFullPath($base)) 'ssl/truststore.p12'
}

function Install-SonarPublicCertificate {
    param([string]$Keytool, [string]$Truststore, [Uri]$Server,
        [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    $directory = Split-Path -Parent $Truststore
    $null = [IO.Directory]::CreateDirectory($directory)
    $staging = Join-Path $directory ('.sonar-cert-' + [guid]::NewGuid().ToString('N'))
    $certificateFile = $staging + '.cer'
    $storeFile = $staging + '.p12'
    $lock = $null
    try {
        # Serializa preparos deste harness, sem apagar lock pertencente a outra execucao.
        $lock = [IO.File]::Open(($Truststore + '.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        $existed = Test-Path -LiteralPath $Truststore
        $originalHash = $null
        if ($existed) {
            $item = Get-Item -LiteralPath $Truststore -Force
            if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Truststore deve ser arquivo regular.' }
            $originalHash = (Get-FileHash -LiteralPath $Truststore -Algorithm SHA256).Hash
            [IO.File]::Copy($Truststore, $storeFile, $false)
        }
        [IO.File]::WriteAllBytes($certificateFile, $Certificate.RawData)
        $fingerprint = Get-SonarCertificateFingerprint $Certificate
        $alias = 'sonar-' + $Server.DnsSafeHost.ToLowerInvariant() + '-' + $Server.Port + '-' + $fingerprint.ToLowerInvariant()
        if ($existed) {
            # Repetir preparo do mesmo certificado nao altera o arquivo.
            $existingPem = Invoke-SonarKeytool $Keytool @('-list','-rfc','-keystore',$storeFile,'-storetype','PKCS12','-storepass','changeit')
            $base64 = [Convert]::ToBase64String($Certificate.RawData)
            if (($existingPem -replace '\s','').Contains($base64)) { return }
        }
        $null = Invoke-SonarKeytool $Keytool @('-importcert','-noprompt','-alias',$alias,'-file',$certificateFile,
            '-keystore',$storeFile,'-storetype','PKCS12','-storepass','changeit')
        $null = Invoke-SonarKeytool $Keytool @('-list','-alias',$alias,'-keystore',$storeFile,'-storetype','PKCS12','-storepass','changeit')
        if ($existed) {
            if ((Get-FileHash -LiteralPath $Truststore -Algorithm SHA256).Hash -cne $originalHash) { throw 'Truststore mudou durante o preparo. Repita a conferencia.' }
            [IO.File]::Replace($storeFile, $Truststore, [NullString]::Value)
        } else { [IO.File]::Move($storeFile, $Truststore) }
    } finally {
        foreach ($file in @($certificateFile,$storeFile)) { if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file -Force } }
        if ($null -ne $lock) { $lock.Dispose() }
    }
}

function Initialize-HarnessSonarCertificate {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ServerUrl,
        [Parameter(Mandatory=$true)][string]$ScannerJdkHome, [switch]$PrepareCertificate)
    $server = [Uri]$ServerUrl
    if (-not $server.IsAbsoluteUri -or $server.UserInfo -or $server.Query -or $server.Fragment -or $server.Scheme -notin @('http','https')) {
        throw 'Informe a URL final do Sonar sem credenciais, query ou fragmento.'
    }
    if ($server.Scheme -eq 'http') {
        if (-not $server.IsLoopback) { throw 'HTTP permitido somente no Sonar local.' }
        if ($PrepareCertificate) { throw 'Preparo de certificado exige HTTPS.' }
        return
    }
    $truststore = Get-SonarDefaultTruststore
    if ((Test-Path -LiteralPath $truststore -PathType Leaf) -and -not $PrepareCertificate) {
        Write-Host "Scanner reutilizara o truststore: $truststore"
        return
    }
    if (-not $PrepareCertificate) {
        $choice = Read-Host 'Certificado Sonar: Enter usa confianca Windows/JDK; c prepara certificado corporativo; q cancela'
        if ([string]::IsNullOrWhiteSpace($choice)) { return }
        if ($choice -cne 'c') { throw 'Preparo cancelado; analise nao iniciada.' }
    }
    $keytool = Join-Path $ScannerJdkHome 'bin/keytool.exe'
    if (-not (Test-Path -LiteralPath $keytool -PathType Leaf)) { throw "keytool ausente no JDK do scanner: $keytool" }
    Write-Host "Obtendo certificado publico de $($server.Authority), por conexao direta..."
    $certificate = Get-SonarPresentedCertificate $keytool $server
    try {
        $fingerprint = Get-SonarCertificateFingerprint $certificate
        Write-Host ('Titular: ' + ($certificate.Subject -replace '[\x00-\x1f\x7f]',' '))
        Write-Host ('Emissor: ' + ($certificate.Issuer -replace '[\x00-\x1f\x7f]',' '))
        Write-Host ("Validade UTC: {0:u} ate {1:u}" -f $certificate.NotBefore.ToUniversalTime(), $certificate.NotAfter.ToUniversalTime())
        Write-Host "SHA-256: $fingerprint"
        Write-Host "Destino: $truststore"
        if ($certificate.NotBefore.ToUniversalTime() -gt [DateTime]::UtcNow -or $certificate.NotAfter.ToUniversalTime() -le [DateTime]::UtcNow) {
            throw 'Certificado fora da validade. Solicite a regularizacao ao responsavel pelo servidor.'
        }
        Write-Host 'Confira a impressao com a equipe responsavel ou outra fonte corporativa confiavel. A coleta acima nao comprova identidade.'
        $expected = Read-Host 'Cole o SHA-256 confirmado para autorizar a importacao (Enter cancela)'
        $expected = $expected -replace '[:\s]',''
        if ($expected -notmatch '^[A-Fa-f0-9]{64}$' -or $expected -ine $fingerprint) {
            throw 'Impressao nao confirmada; truststore preservado e analise nao iniciada.'
        }
        Install-SonarPublicCertificate $keytool $truststore $server $certificate
        Write-Host "Certificado preparado em $truststore. Validacao TLS permanece ativa."
    } finally { if ($null -ne $certificate) { $certificate.Dispose() } }
}

Export-ModuleMember -Function Initialize-HarnessSonarCertificate
