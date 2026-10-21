[CmdletBinding()]
param(
    [ValidateSet('all','sync','build','ib','image','shell')]
    [string]$Stage = 'all',
    [string]$Repo = '',
    [string]$OutDir = '',
    [string]$Packages = 'luci luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-app-passwall luci-i18n-passwall-zh-cn easytier-noweb luci-app-easytier',
    [string]$ExtraName = 'passwall-easytier',
    [string]$Image = 'opizero2-builder:24.04',
    [string]$Volume = 'opizero2-build',
    [string]$Container = 'opiz2',
    [switch]$RebuildImage
)

$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = Split-Path $PSScriptRoot -Parent }
if (-not $OutDir) { $OutDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'images' }
$Repo = (Resolve-Path $Repo).Path
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path

function Invoke-Docker {
    param([string[]]$DockerArgs, [switch]$Quiet)
    if ($Quiet) { docker @DockerArgs 2>$null | Out-Null } else { docker @DockerArgs }
    if ($LASTEXITCODE -ne 0) { throw "docker $($DockerArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

if ($RebuildImage -or -not (docker image inspect $Image 2>$null)) {
    Write-Host "== building docker image $Image =="
    Invoke-Docker -DockerArgs @('build','-t',$Image,$PSScriptRoot)
}

Invoke-Docker -DockerArgs @('volume','create',$Volume) -Quiet

$running = docker ps -a --filter "name=^/$Container$" --format '{{.Names}}'
if ($running) { Invoke-Docker -DockerArgs @('rm','-f',$Container) -Quiet }

Write-Host "== starting container $Container =="
Invoke-Docker -DockerArgs @(
    'run','-d','--name',$Container,'--hostname','opiz2',
    '-v',"${Repo}:/src",
    '-v',"${OutDir}:/out",
    '-v',"${Volume}:/build",
    '-w','/build',
    $Image,'sleep','infinity'
) -Quiet

function Invoke-Stage([string]$name) {
    Write-Host "== stage: $name =="
    switch ($name) {
        'sync'  { Invoke-Docker -DockerArgs @('exec',$Container,'bash','/src/zero2-build/scripts/00-sync.sh') }
        'build' { Invoke-Docker -DockerArgs @('exec',$Container,'bash','/src/zero2-build/scripts/10-build.sh') }
        'ib'    { Invoke-Docker -DockerArgs @('exec',$Container,'bash','/src/zero2-build/scripts/20-imagebuilder.sh') }
        'image' {
            $envFile = Join-Path $env:TEMP "zero2-build-env-$PID"
            [System.IO.File]::WriteAllText($envFile,
                "PACKAGES=$Packages`nEXTRA_IMAGE_NAME=$ExtraName`n", (New-Object System.Text.UTF8Encoding($false)))
            try {
                Invoke-Docker -DockerArgs @('exec','--env-file',$envFile,
                    $Container,'bash','/src/zero2-build/scripts/30-pack-image.sh')
            } finally { Remove-Item $envFile -Force -ErrorAction SilentlyContinue }
        }
        'shell' { docker exec -it $Container bash }
        'all'   { }
    }
}

if ($Stage -eq 'all') {
    foreach ($s in 'sync','build','ib','image') { Invoke-Stage $s }
} else {
    Invoke-Stage $Stage
}

Write-Host ""
Write-Host "output: $OutDir"
Get-ChildItem $OutDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
    Format-Table Name, Length, LastWriteTime -AutoSize
exit 0