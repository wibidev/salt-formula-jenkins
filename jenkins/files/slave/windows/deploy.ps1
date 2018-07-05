{%- from "jenkins/map.jinja" import slave with context %}
<#  ===========================
   SYNOPSIS:
   * Install Jenkins slave as a service using NSSM
   * Requires:
   *   - NSSM installed
   *   - nssmpath set in pillars
   =========================== #>

<# ===========================
   Parameters:
   e: environment { required: alpha|release|beta|preproduction|production }
   i: instance { required: wib-dev-beta|wib-tst-beta|wibifirst|frd025d01dbw|frd025p01mxw|f2d025p01few|f2d025p02few }
   a: action, deploy or remove service { optional: {default start} start|stop}
   =========================== #>

<# ===========================
   Examples:
   deploy.ps1 -p production -i prod1
   =========================== #>

param(
    [Parameter(Mandatory=$False)]
    [string] $a = "start"
)

$action = $a


<#  ===========================
    Utils Function
    =========================== #>

function Info {
    param (
        [Parameter(Position=0)]
        [string] $Msg = ""
    )

    Write-Host "[" -NoNewline
    Write-Host "INFO" -NoNewline -ForegroundColor Cyan
    Write-Host "]" (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") "- " -NoNewline
    Write-Host $($Msg)
}

function Success {
    param (
        [Parameter(Position=0)]
        [string] $Msg = ""
    )

    Write-Host "[" -NoNewline
    Write-Host "OK" -NoNewline -ForegroundColor Green
    Write-Host "]" (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") "- " -NoNewline
    Write-Host $($Msg)
}

function Warning {
    param (
        [Parameter(Position=0)]
        [string] $Msg = ""
    )

    Write-Host "[" -NoNewline
    Write-Host "WARNING" -NoNewline -ForegroundColor Yellow
    Write-Host "]" (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") "- " -NoNewline
    Write-Host $($Msg)
}

function Alert {
    param (
        [Parameter(Position=0)]
        [string] $Msg = ""
    )

    Write-Host "[" -NoNewline
    Write-Host "ERROR" -NoNewline -ForegroundColor Red
    Write-Host "]" (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") "- " -NoNewline
    Write-Host $($Msg)
}


<# ===========================
   Functions
   =========================== #>

function _ifServiceAlreadyExits {
    if ( Get-Service "$service" -ErrorAction SilentlyContinue ) {
        return $True
    }
    return $False
}

function _installService {
    Info -Msg "Installing service $service..."
    $jenkinsHome = "{{ slave.jenkinshome }}"
    $jenkinsUrl = "{{ slave.master.protocol }}://{{ slave.master.host }}:{{ slave.master.port }}"
    $jenkinsCredentials = "{{ slave.user.name }}:{{ slave.user.password }}"
    $jenkinsCommand = "java -jar $jenkinsHome/agent.jar -jnlpUrl $jenkinsUrl/computer/{{ slave.hostname }}/slave-agent.jnlp -jnlpCredentials `"$jenkinsCredentials`""
    Invoke-RestMethod -Uri "$jenkinsUrl/jnlpJars/agent.jar" -Method "GET" -OutFile "$jenkinsHome/agent.jar"
    Start-Process -FilePath $nssm -ArgumentList "install $service $jenkinsCommand" -NoNewWindow -Wait
    $jenkinsUser = "$env:COMPUTERNAME\{{ slave.runner.name }}"
    $jenkinsPwd = "{{ slave.runner.password }}"
    Start-Process -FilePath $nssm -ArgumentList "set $service ObjectName $jenkinsUser $jenkinsPwd" -NoNewWindow -Wait
    Start-Process -FilePath $nssm -ArgumentList "set $service DisplayName $service" -NoNewWindow -Wait
    Start-Process -FilePath $nssm -ArgumentList "set $service Description $service" -NoNewWindow -Wait
    Success -Msg "Service $service installed!"
}

function _removeService {
    Warning -Msg "Removing service $service..."
    Start-Process -FilePath $nssm -ArgumentList "stop $service confirm" -NoNewWindow -Wait
    Start-Process -FilePath $nssm -ArgumentList "remove $service confirm" -NoNewWindow -Wait
    Success -Msg "Service $service removed!"
}

function _startService {
    Info -Msg "Starting service $service..."
    Start-Process -FilePath $nssm -ArgumentList "start $service" -NoNewWindow -Wait
    Info -Msg "Service $service started!"
}

function _deployService {
    if (_ifServiceAlreadyExits) {
        Warning -Msg "Service already exits"
        _removeService
    }
    _installService
    _startService
}


<# ===========================
   Startup
   =========================== #>

try {
    Info -Msg "Deploying Jenkins slave as a service..."
    $service = "{{ slave.service }}"
    $nssm = "{{ slave.nssmpath }}"
    switch ($action) {
        "start" { _deployService }
        "stop" { _removeService }
        default { throw "Unknown action option $action" }
    }
    Success -Msg "Jenkins slave service deployed!"
} catch {
  Alert -Msg $_.Exception.Message
  throw $_.Exception
}
