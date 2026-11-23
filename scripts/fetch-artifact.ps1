<#
.SYNOPSIS
    从 GitHub Actions 下载最新成功构建产物的 dylib，保存到本地 artifacts/dylib/ 目录。

.DESCRIPTION
    - 从本机 Git 凭据管理器读取 GitHub token（不要求用户交出账号密码）
    - 找到仓库最近一次成功的 "build deb" run
    - 下载其 artifact，解出其中的 .dylib
    - 以 DYYY_<version>_run<run-id>.dylib 命名保存，并打印 SHA-256
    - 重复运行同一个 run 时会跳过已存在文件

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/fetch-artifact.ps1
#>
param(
    [string]$Repo = 'Yang-tfs/DYYY',
    [long]$RunId = 0,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------- 1. 读取本机 Git 凭据里的 token ----------
$credInput = "protocol=https`nhost=github.com`n`n"
$cred = $credInput | git credential fill 2>$null
$passwordLine = $cred | Where-Object { $_ -like 'password=*' } | Select-Object -First 1
if (-not $passwordLine) { throw '未找到 GitHub 凭据（git credential fill 无返回）。请先在本机登录 GitHub。' }
$token = ($passwordLine -replace '^password=', '')
$headers = @{
    'User-Agent' = 'dsh-artifact-fetcher'
    'Accept' = 'application/vnd.github+json'
    'Authorization' = "Bearer $token"
}
$api = "https://api.github.com/repos/$Repo/actions"

# ---------- 2. 确定目标 run ----------
if ($RunId -le 0) {
    $runs = Invoke-RestMethod -Uri "$api/runs?status=success&per_page=20" -Headers $headers -TimeoutSec 30
    $run = $runs.workflow_runs | Where-Object { $_.name -eq 'build deb' } | Select-Object -First 1
    if (-not $run) { throw '没有找到成功的 build deb run' }
    $RunId = $run.id
} else {
    $run = Invoke-RestMethod -Uri "$api/runs/$RunId" -Headers $headers -TimeoutSec 30
    if ($run.status -ne 'completed' -or $run.conclusion -ne 'success') {
        throw "run $RunId 不是成功状态：$($run.status)/$($run.conclusion)"
    }
}
Write-Host "使用 run $RunId  ($($run.created_at))  $($run.html_url)"

# ---------- 3. 解析版本号与产物 ----------
$control = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/contents/control?ref=$($run.head_sha)" -Headers $headers -TimeoutSec 30
$versionText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($control.content -replace '\s', '')))
$version = ([regex]::Match($versionText, '(?m)^Version:\s*(\S+)')).Groups[1].Value
if (-not $version) { $version = 'unknown' }

$arts = Invoke-RestMethod -Uri "$api/runs/$RunId/artifacts" -Headers $headers -TimeoutSec 30
$art = $arts.artifacts | Select-Object -First 1
if (-not $art) { throw "run $RunId 没有产物" }

$destDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\dylib'
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$dest = Join-Path $destDir "DYYY_${version}_run${RunId}.dylib"
if ((Test-Path $dest) -and -not $Force) {
    Write-Host "已存在，跳过：$dest"
    Write-Host "SHA-256: $((Get-FileHash $dest -Algorithm SHA256).Hash)"
    return
}

# ---------- 4. 下载并解出 dylib ----------
$zip = Join-Path $env:TEMP "dyyy-artifact-$RunId.zip"
$tmp = Join-Path $env:TEMP "dyyy-artifact-$RunId-extract"
Write-Host "下载 artifact: $($art.name) ..."
Invoke-WebRequest -Uri $art.archive_download_url -Headers $headers -TimeoutSec 120 -OutFile $zip
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
[System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
$dylib = Get-ChildItem -Recurse $tmp -Filter '*.dylib' | Select-Object -First 1
if (-not $dylib) { throw "artifact 中找不到 dylib" }
Copy-Item $dylib.FullName $dest -Force

Write-Host "已保存：$dest"
Write-Host "大小：$([math]::Round((Get-Item $dest).Length/1MB, 2)) MB"
Write-Host "SHA-256: $((Get-FileHash $dest -Algorithm SHA256).Hash)"

Remove-Item -Recurse -Force $tmp, $zip -ErrorAction SilentlyContinue
