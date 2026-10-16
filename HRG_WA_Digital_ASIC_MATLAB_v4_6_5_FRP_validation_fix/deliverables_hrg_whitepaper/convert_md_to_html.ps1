param(
    [Parameter(Mandatory = $true)][string]$InputFile,
    [Parameter(Mandatory = $true)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'
$lines = Get-Content -LiteralPath $InputFile -Encoding UTF8
$body = [System.Text.StringBuilder]::new()
$paragraph = [System.Collections.Generic.List[string]]::new()
$inCode = $false
$code = [System.Collections.Generic.List[string]]::new()
$listType = $null

function Convert-Inline([string]$text) {
    $encoded = [Net.WebUtility]::HtmlEncode($text)
    $encoded = [regex]::Replace($encoded, '\[([^\]]+)\]\((https?://[^\)]+)\)', '<a href="$2">$1</a>')
    $encoded = [regex]::Replace($encoded, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    $encoded = [regex]::Replace($encoded, '`([^`]+)`', '<code>$1</code>')
    return $encoded
}

function Close-Paragraph {
    if ($paragraph.Count -gt 0) {
        [void]$body.AppendLine('<p>' + (Convert-Inline ($paragraph -join ' ')) + '</p>')
        $paragraph.Clear()
    }
}

function Close-List {
    if ($listType) {
        [void]$body.AppendLine("</$listType>")
        $script:listType = $null
    }
}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^```') {
        Close-Paragraph
        Close-List
        if (-not $inCode) {
            $inCode = $true
            $code.Clear()
        } else {
            [void]$body.AppendLine('<pre><code>' + [Net.WebUtility]::HtmlEncode(($code -join "`n")) + '</code></pre>')
            $inCode = $false
        }
        continue
    }
    if ($inCode) {
        $code.Add($line)
        continue
    }
    if ($line -match '^\s*$') {
        Close-Paragraph
        Close-List
        continue
    }
    if ($line -match '^---+$') {
        Close-Paragraph
        Close-List
        [void]$body.AppendLine('<hr>')
        continue
    }
    if ($line -match '^(#{1,6})\s+(.+)$') {
        Close-Paragraph
        Close-List
        $level = $matches[1].Length
        [void]$body.AppendLine("<h$level>" + (Convert-Inline $matches[2]) + "</h$level>")
        continue
    }
    if ($line.TrimStart().StartsWith('|') -and $i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*\|?\s*:?-{3,}') {
        Close-Paragraph
        Close-List
        $headers = $line.Trim().Trim('|').Split('|')
        [void]$body.AppendLine('<table><thead><tr>')
        foreach ($cell in $headers) { [void]$body.AppendLine('<th>' + (Convert-Inline $cell.Trim()) + '</th>') }
        [void]$body.AppendLine('</tr></thead><tbody>')
        $i += 2
        while ($i -lt $lines.Count -and $lines[$i].TrimStart().StartsWith('|')) {
            $cells = $lines[$i].Trim().Trim('|').Split('|')
            [void]$body.AppendLine('<tr>')
            foreach ($cell in $cells) { [void]$body.AppendLine('<td>' + (Convert-Inline $cell.Trim()) + '</td>') }
            [void]$body.AppendLine('</tr>')
            $i++
        }
        [void]$body.AppendLine('</tbody></table>')
        $i--
        continue
    }
    if ($line -match '^\s*-\s+(.+)$') {
        Close-Paragraph
        if ($listType -ne 'ul') { Close-List; $listType = 'ul'; [void]$body.AppendLine('<ul>') }
        [void]$body.AppendLine('<li>' + (Convert-Inline $matches[1]) + '</li>')
        continue
    }
    if ($line -match '^\s*\d+\.\s+(.+)$') {
        Close-Paragraph
        if ($listType -ne 'ol') { Close-List; $listType = 'ol'; [void]$body.AppendLine('<ol>') }
        [void]$body.AppendLine('<li>' + (Convert-Inline $matches[1]) + '</li>')
        continue
    }
    if ($line -match '^>\s*(.+)$') {
        Close-Paragraph
        Close-List
        [void]$body.AppendLine('<blockquote>' + (Convert-Inline $matches[1]) + '</blockquote>')
        continue
    }
    $paragraph.Add($line.Trim())
}
Close-Paragraph
Close-List

$title = '半球谐振陀螺技术详解白皮书'
$html = @"
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>
@page { size: A4; margin: 20mm 18mm 20mm 18mm; }
body { font-family: "Microsoft YaHei", "Noto Sans CJK SC", sans-serif; color:#20252b; line-height:1.72; max-width:980px; margin:0 auto; padding:28px; font-size:11pt; }
h1 { font-size:28pt; text-align:center; margin:35mm 0 18mm; color:#163a5f; page-break-before:always; }
h1:first-of-type { page-break-before:auto; }
h2 { font-size:18pt; color:#174f7c; border-bottom:2px solid #7da8c8; padding-bottom:6px; margin-top:28px; page-break-after:avoid; }
h3 { font-size:14pt; color:#245f87; margin-top:22px; page-break-after:avoid; }
p { text-align:justify; margin:8px 0; }
table { border-collapse:collapse; width:100%; margin:14px 0; font-size:9.5pt; page-break-inside:avoid; }
th, td { border:1px solid #9aa9b5; padding:6px 8px; vertical-align:top; }
th { background:#dceaf4; color:#153a55; }
tr:nth-child(even) td { background:#f7fafc; }
code { font-family:Consolas, monospace; background:#eef2f5; padding:1px 4px; border-radius:3px; }
pre { background:#17212b; color:#e8edf2; padding:12px; border-radius:5px; white-space:pre-wrap; }
blockquote { border-left:4px solid #3c83b7; padding:10px 15px; background:#eef6fb; font-weight:600; }
a { color:#0b66a3; text-decoration:none; }
hr { border:0; border-top:1px solid #bac7d0; margin:25px 0; }
li { margin:4px 0; }
@media print { body { max-width:none; padding:0; } a { color:#20252b; } }
</style>
</head>
<body>
$body
</body>
</html>
"@
[IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Parent $OutputFile)).Path + [IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $OutputFile), $html, [Text.UTF8Encoding]::new($false))
