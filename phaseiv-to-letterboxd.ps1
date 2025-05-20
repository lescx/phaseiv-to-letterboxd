$apiKey = ""
$inputFilePath = "medienliste_phaseiv.txt"
$outputFilePath = "prototype-letterboxd.csv"
$failedFilePath = "prototype-failed.txt"

# Read the movie library file
$movies = Get-Content -Path $inputFilePath

# Initialize arrays for the results and failed entries
$letterboxdMovies = @()
$failedEntries = @()

# Function to fetch movie details from TMDb by German title
function Get-MovieDetails {
    param (
        [string]$germanTitle
    )

    $encodedTitle = [System.Uri]::EscapeDataString($germanTitle)
    $apiUrl = "https://api.themoviedb.org/3/search/movie?query=$encodedTitle&language=de&api_key=$apiKey"

    try {
        $headers = @{
            "Accept" = "application/json"
            "Content-Type" = "application/json; charset=utf-8"
        }

        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

        if ($response.total_results -gt 0) {
            $movie = $response.results[0]
            return [PSCustomObject]@{
                Title      = $movie.original_title
                Year       = [datetime]::Parse($movie.release_date).Year
                tmdbID     = $movie.id
            }
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

# Process each line in the movie library
foreach ($line in $movies) {
    $fields = $line -split ";"

    # Check if the second field is '0' (not actually in Phase IV). If it's not, skip this entry.
    if ($fields[1].Trim() -ne "0") {
        continue
    }

    # Extract the German title from the 4th column (index 3)
    $germanTitle = $fields[3].Trim()

    Write-Host "Processing: $germanTitle"

    $movieDetails = Get-MovieDetails -germanTitle $germanTitle

    if ($movieDetails) {
        # If movie details were found, add it to the Letterboxd CSV data
        $letterboxdMovies += [PSCustomObject]@{
            Title   = $movieDetails.Title
            Year    = $movieDetails.Year
            tmdbID  = $movieDetails.tmdbID
        }
    } else {
        # If movie details were not found, log it to the failed entries
        $failedEntries += $line
    }
}

$letterboxdMovies | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding utf8bom
$failedEntries | Out-File -FilePath $failedFilePath -Encoding utf8bom

Write-Host "Movie data has been exported to $outputFilePath"
Write-Host "Failed entries have been saved to $failedFilePath"