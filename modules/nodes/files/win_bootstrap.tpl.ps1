<powershell>

# set templatefile and local parameters
$HOSTNAME="${hostname}"
$ZONE="${zone}"
$PE_PRIMARY="${pe_primary}"
$ROLE="${role}"
$ENVIRONMENT="${environment}"
$FQDN="$HOSTNAME.$ZONE"

# retry loop to download and install puppet agent
:loop while ($true) {
  [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
  $webclient = New-Object system.net.webclient
  $webclient.DownloadFile("https://$${PE_PRIMARY}:8140/packages/current/install.ps1", "C:\pe_install.ps1")
  if (Test-Path "C:\pe_install.ps1") {
    sleep 1
    Write-Verbose "starting installation"
    Invoke-Expression -Command "C:\pe_install.ps1 agent:certname=$${FQDN} extension_requests:pp_role=$ROLE extension_requests:pp_environment=$ENVIRONMENT extension_requests:pp_hostname=$FQDN extension_requests:pp_zone=$ZONE"
    sleep 60 # allow for initial puppet agent run
    break loop
  }
  else {
    Write-Verbose "waiting on puppet primary"
    sleep 5
  }
}

# do a few puppet runs
$n=1
$t=10
while ($n -le $t) {
  Get-Date -Format "HH:mm:ss"
  Write-Verbose "running puppet agent"
  & "C:\Program Files\Puppet Labs\Puppet\bin\puppet.bat" "agent" "-t"
  Write-Verbose "puppet agent run complete"
  sleep 30
  $n+=1
}

</powershell>
