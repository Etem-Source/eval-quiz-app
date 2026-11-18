[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$RG  = "rg-quiz-app"
$LOC = "francecentral"
$ACR = "acrquizetem"
$ENV_NAME = "env-quiz-std"
$TAG = git rev-parse --short HEAD
Write-Host "RG=$RG ACR=$ACR TAG=$TAG"
