# Main script parameters
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath
    
    #[Parameter()]
    #[switch]$Verbose
)

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

function Remove-SelectiveObfuscation {
    <#
    .SYNOPSIS
        Selectively removes obfuscation patterns from batch files which have been obfuscated by BatCloak.
    
    .DESCRIPTION
        Removes the pattern %[or .]*% from lines that:
        1. Start with @
        2. Start with the letter 's'
        3. Start with % followed by four ASCII characters and another %
        Other lines are left unchanged.
    
    .PARAMETER InputText
        Path of file to deobfuscate.
    
    .EXAMPLE
        BatVision.ps1 [File name]
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$InputText
    )
    
    process {
        # Split input into lines
        $lines = $InputText -split "`r?`n"
        $processedLines = @()
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            
            # Check if line matches our criteria for processing
            $shouldProcess = $false
            
            # Criteria 1: Lines that start with @
            if ($trimmedLine -match '^@') {
                $shouldProcess = $true
                Write-Verbose "Processing line starting with @: $trimmedLine"
            }
            # Criteria 2: Lines that start with the letter 's'
            elseif ($trimmedLine -match '^s') {
                $shouldProcess = $true
                Write-Verbose "Processing line starting with 's': $trimmedLine"
            }
            # Criteria 3: Lines that start with % followed by four ASCII characters and another %
            elseif ($trimmedLine -match '^%[!-~]{4}%') {
                $shouldProcess = $true
                Write-Verbose "Processing line starting with %xxxx%: $trimmedLine"
            }
			# Criteria 4: Lines that start with the letter 'C'
			elseif ($trimmedLine -match '^C') {
				$shouldProcess = $true
				Write-Verbose "Processing line starting with 'C': $trimmedLine"
			}
			# Criteria 5: Lines that start with a space ' '
			elseif ($trimmedLine -match '^ ') {
				$shouldProcess = $true
				Write-Verbose "Processing line starting with ' ': $trimmedLine"
			}
            else {
                Write-Verbose "Skipping line (doesn't match criteria): $trimmedLine"
            }
            
            if ($shouldProcess) {
                # Apply the regex to remove non-ascii characters as well as other characters found between the % symbols.
                $cleanedLine = $trimmedLine -replace '%([^\x00-\x7F]|o|r| |\.)+%', ''

                # Round two of removing the leftover non-ascii characters.
				if ($cleanedLine -match "(%[a-zA-Z]{4})(([^\x00-\x7F]|r|o|\.| )+)")
                {
                    if ($Matches[2] -eq '.')
                    {
                        # It may be the case a single . gets leftover from the match above. If so, it needs a delimiter to be treated as a period rather than a regex character.
						$cleanedLine2 = $cleanedLine -replace '\.', ''
					    $processedLines += $cleanedLine2
                    }
                    else
                    {
                        $cleanedLine2 = $cleanedLine -replace $matches[2], ''
					    $processedLines += $cleanedLine2
                    }
                }
				else
				{
					$processedLines += $cleanedLine
				}
				
            }
            else {
                # Leave the line unchanged
                $processedLines += $trimmedLine
            }
        }
        
        return $processedLines -join "`r`n"
    }
}


try {
    # Get file information
    $fileInfo = Get-Item $FilePath
    $directory = $fileInfo.Directory.FullName
    $baseName = $fileInfo.BaseName
    $extension = $fileInfo.Extension
    
    # Create output filename
    $outputFileName = "${baseName}_deobfuscated${extension}"
    $outputPath = Join-Path $directory $outputFileName
    
    Write-Host "=== BAT VISION DEOBFUSCATOR ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Input file:  " -NoNewline -ForegroundColor Yellow
    Write-Host $FilePath -ForegroundColor White
    Write-Host "Output file: " -NoNewline -ForegroundColor Yellow
    Write-Host $outputPath -ForegroundColor White
    Write-Host ""
    
    # Read the input file
    Write-Host "Reading input file..." -ForegroundColor Green
    $inputContent = Get-Content $FilePath -Raw -Encoding UTF8
    
    if ([string]::IsNullOrWhiteSpace($inputContent)) {
        Write-Warning "Input file appears to be empty."
        exit 1
    }
    
    # Process the content
    Write-Host "Processing obfuscated content..." -ForegroundColor Green
    if ($Verbose) {
        $result = Remove-SelectiveObfuscation -InputText $inputContent -Verbose
    } else {
        $result = Remove-SelectiveObfuscation -InputText $inputContent
    }
    
    # Write to output file
    Write-Host "Writing deobfuscated content to output file..." -ForegroundColor Green
    $result | Out-File -FilePath $outputPath -Encoding UTF8
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Deobfuscated file saved to: $outputPath" -ForegroundColor White
    Write-Host ""
    
    # Show file sizes for comparison
    $inputSize = (Get-Item $FilePath).Length
    $outputSize = (Get-Item $outputPath).Length
    
    Write-Host "File size comparison:" -ForegroundColor Cyan
    Write-Host "  Input:  $inputSize bytes" -ForegroundColor Gray
    Write-Host "  Output: $outputSize bytes" -ForegroundColor Gray
    Write-Host "  Reduction: $($inputSize - $outputSize) bytes" -ForegroundColor Gray
    
    # Optionally show a preview of the results
    $showPreview = Read-Host "`nShow preview of deobfuscated content? (y/n)"
    if ($showPreview -eq 'y' -or $showPreview -eq 'Y') {
        Write-Host ""
        Write-Host "=== PREVIEW OF DEOBFUSCATED CONTENT ===" -ForegroundColor Cyan
        $previewLines = $result -split "`n" | Select-Object -First 10
        foreach ($line in $previewLines) {
            Write-Host $line -ForegroundColor White
        }
        if (($result -split "`n").Count -gt 10) {
            Write-Host "... (showing first 10 lines)" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
