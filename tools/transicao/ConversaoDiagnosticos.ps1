function Get-ConversionExecutionDates($Data,[string]$Label) {
    $dates=@(foreach ($field in @('StartedAtUtc','FinishedAtUtc')) {
        $value=[string](Get-LegacyValue $Data $field)
        $date=[DateTimeOffset]::MinValue
        if ($value -notmatch '^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$' -or -not [DateTimeOffset]::TryParse($value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) { throw ($Label+': data de execucao ausente/invalida ou sem fuso.') }
        $date
    })
    if ($dates[1] -lt $dates[0]) { throw ($Label+': fim anterior ao inicio declarado.') }
    [pscustomobject]@{Started=$dates[0];Finished=$dates[1]}
}

function Select-ConversionNewest($Candidates,[string]$Choice) {
    $ordered=@($Candidates | Sort-Object Finished -Descending)
    if (-not $ordered.Count) { return }
    if (@($ordered | Where-Object Finished -EQ $ordered[0].Finished).Count -ne 1) { throw ('Tentativas empatadas; escolha '+$Choice+' explicitamente.') }
    $ordered[0]
}
