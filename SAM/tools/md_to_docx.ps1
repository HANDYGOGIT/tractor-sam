param(
    [string]$MarkdownPath = "",
    [string]$OutputDocxPath = ""
)

if (-not (Test-Path -LiteralPath $MarkdownPath)) {
    Write-Error "Markdown file not found: $MarkdownPath"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($OutputDocxPath)) {
    $OutputDocxPath = [System.IO.Path]::ChangeExtension($MarkdownPath, ".docx")
}

$md = Get-Content -LiteralPath $MarkdownPath -Raw

# Very minimal Markdown -> HTML (covers headings, lists, code fences, inline code, bold, italics, links)
$htmlLines = New-Object System.Collections.Generic.List[string]

$inCodeBlock = $false
foreach ($line in ($md -split "`n")) {
    if ($line -match '^```') {
        if (-not $inCodeBlock) {
            $htmlLines.Add('<pre><code>')
            $inCodeBlock = $true
        } else {
            $htmlLines.Add('</code></pre>')
            $inCodeBlock = $false
        }
        continue
    }

    if ($inCodeBlock) {
        # HTML-escape
        $esc = $line -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
        $htmlLines.Add($esc)
        continue
    }

    # Headings
    if ($line -match '^(#{1,6})\s+(.*)$') {
        $level = $matches[1].Length
        $text = $matches[2]
        $htmlLines.Add("<h$level>$text</h$level>")
        continue
    }

    # Unordered lists
    if ($line -match '^\s*[-*]\s+(.*)$') {
        $item = $matches[1]
        # Start list if previous line wasn't in a <ul>
        if (($htmlLines.Count -eq 0) -or (-not $htmlLines[$htmlLines.Count-1].StartsWith('<ul>')) -and (-not $htmlLines[$htmlLines.Count-1].StartsWith('<li>'))) {
            $htmlLines.Add('<ul>')
        }
        $htmlLines.Add("<li>$item</li>")
        # Peek ahead handled later (we'll close lists after loop)
        continue
    }

    # Ordered lists
    if ($line -match '^\s*\d+\.\s+(.*)$') {
        $item = $matches[1]
        if (($htmlLines.Count -eq 0) -or (-not $htmlLines[$htmlLines.Count-1].StartsWith('<ol>')) -and (-not $htmlLines[$htmlLines.Count-1].StartsWith('<li>'))) {
            $htmlLines.Add('<ol>')
        }
        $htmlLines.Add("<li>$item</li>")
        continue
    }

    # Close any open lists if we hit a blank or paragraph
    if ($line.Trim().Length -eq 0) {
        if ($htmlLines.Count -gt 0) {
            $last = $htmlLines[$htmlLines.Count-1]
            if ($last.StartsWith('<li>')) {
                # Find the nearest opening list tag and close appropriately
                $openTag = ($htmlLines | Select-String -Pattern '^<ul>$|^<ol>$' -SimpleMatch | Select-Object -Last 1).Line
                if ($openTag -eq '<ul>') { $htmlLines.Add('</ul>') }
                elseif ($openTag -eq '<ol>') { $htmlLines.Add('</ol>') }
            }
        }
        $htmlLines.Add('<p></p>')
        continue
    }

    # Inline formatting for normal paragraphs
    $p = $line
    # Links [text](url)
    $p = [System.Text.RegularExpressions.Regex]::Replace($p, '\[(.*?)\]\((.*?)\)', '<a href="$2">$1</a>')
    # Bold **text**
    $p = [System.Text.RegularExpressions.Regex]::Replace($p, '\*\*(.*?)\*\*', '<strong>$1</strong>')
    # Italic *text* or _text_
    $p = [System.Text.RegularExpressions.Regex]::Replace($p, '(^|[^\*])\*(?!\*)([^\*]+)\*(?!\*)', '$1<em>$2</em>')
    $p = [System.Text.RegularExpressions.Regex]::Replace($p, '_(.*?)_', '<em>$1</em>')
    # Inline code `code`
    $p = [System.Text.RegularExpressions.Regex]::Replace($p, '`([^`]+)`', '<code>$1</code>')
    $htmlLines.Add("<p>$p</p>")
}

# Close list if the file ended with list items
if ($htmlLines.Count -gt 0) {
    $last = $htmlLines[$htmlLines.Count-1]
    if ($last.StartsWith('<li>')) {
        $openTag = ($htmlLines | Select-String -Pattern '^<ul>$|^<ol>$' -SimpleMatch | Select-Object -Last 1).Line
        if ($openTag -eq '<ul>') { $htmlLines.Add('</ul>') }
        elseif ($openTag -eq '<ol>') { $htmlLines.Add('</ol>') }
    }
}

$htmlBody = ($htmlLines -join "`n")
$html = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; line-height: 1.4; }
    pre { background: #f6f8fa; padding: 12px; overflow-x: auto; }
    code { font-family: Consolas, monospace; }
    h1, h2, h3, h4, h5, h6 { margin-top: 1.2em; }
    ul, ol { margin-left: 1.2em; }
  </style>
  <title>Markdown to DOCX</title>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
</head>
<body>
$htmlBody
</body>
</html>
"@

$tempHtml = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.html')
Set-Content -LiteralPath $tempHtml -Value $html -Encoding UTF8

try {
    $word = New-Object -ComObject Word.Application
} catch {
    Write-Error "Microsoft Word is required for this conversion (COM automation)."
    Remove-Item -LiteralPath $tempHtml -ErrorAction SilentlyContinue
    exit 2
}

$word.Visible = $false
$doc = $null
try {
    $doc = $word.Documents.Open($tempHtml)
    # 16 = wdFormatDocumentDefault (.docx)
    $format = 16
    $OutputFull = (Resolve-Path -LiteralPath $OutputDocxPath).Path 2>$null
    if (-not $OutputFull) { $OutputFull = (Resolve-Path -LiteralPath (Split-Path -Parent $OutputDocxPath) 2>$null).Path }
    if (-not $OutputFull) { $OutputFull = (Get-Location).Path }
    $doc.SaveAs([ref] $OutputDocxPath, [ref] $format)
} finally {
    if ($doc -ne $null) { $doc.Close() | Out-Null }
    $word.Quit() | Out-Null
    Remove-Item -LiteralPath $tempHtml -ErrorAction SilentlyContinue
}

Write-Host "Wrote DOCX: $OutputDocxPath"


