<#
.SYNOPSIS
    Sauvegarder Grafana sur un hôte source, rapatrier le dossier,
    le pousser sur un hôte cible, puis exécuter le script de restauration.
.NOTES
    Prérequis : OpenSSH client (ssh, scp) dans le PATH.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------ UI ----------------------------------------
$form              = New-Object Windows.Forms.Form
$form.Text         = 'Grafana – Duplication de volume'
$form.Size         = [Drawing.Size]::new(480,420)
$form.StartPosition= 'CenterScreen'

$lblIntro          = [Windows.Forms.Label]@{Text='Entrez les configs SSH :';Location='10,10';Size='440,20'}
$form.Controls.Add($lblIntro)

# --- champs source
$lblSrcHost = [Windows.Forms.Label]@{Text='SOURCE (IP/FQDN) :';Location='10,40';Size='200,20'}
$txtSrcHost = [Windows.Forms.TextBox]@{Location='220,40';Size='200,20'}
$lblSrcUser = [Windows.Forms.Label]@{Text='Utilisateur SSH source :';Location='10,70';Size='200,20'}
$txtSrcUser = [Windows.Forms.TextBox]@{Location='220,70';Size='200,20'}
$form.Controls.AddRange(@($lblSrcHost,$txtSrcHost,$lblSrcUser,$txtSrcUser))

# --- champs cible
$lblDstHost = [Windows.Forms.Label]@{Text='CIBLE (IP/FQDN) :';Location='10,110';Size='200,20'}
$txtDstHost = [Windows.Forms.TextBox]@{Location='220,110';Size='200,20'}
$lblDstUser = [Windows.Forms.Label]@{Text='Utilisateur SSH cible :';Location='10,140';Size='200,20'}
$txtDstUser = [Windows.Forms.TextBox]@{Location='220,140';Size='200,20'}
$form.Controls.AddRange(@($lblDstHost,$txtDstHost,$lblDstUser,$txtDstUser))

# --- clé privée (facultative)
$lblKey = [Windows.Forms.Label]@{
    Text='(Facultatif) Chemin SSH Key (.pem):'
    Location='10,180';Size='440,20'}
$txtKey = [Windows.Forms.TextBox]@{Location='10,200';Size='410,20'}
$btnBrowse = [Windows.Forms.Button]@{Text='+';Location='425,198';Size='30,24'}
$form.Controls.AddRange(@($lblKey,$txtKey,$btnBrowse))

$ofd = New-Object Windows.Forms.OpenFileDialog
$ofd.Filter = 'Clés SSH (*.pem;*.ppk)|*.pem;*.ppk|Tous les fichiers|*.*'
$btnBrowse.Add_Click({ if($ofd.ShowDialog() -eq 'OK'){ $txtKey.Text = $ofd.FileName } })

# --- bouton principal + zone log
$btnGo  = [Windows.Forms.Button]@{Text='Lancer la duplication';Location='10,240';Size='440,30'}
$txtLog = [Windows.Forms.TextBox]@{
    Multiline=$true;ScrollBars='Vertical';ReadOnly=$true
    Location='10,280';Size='440,80'}
$form.Controls.AddRange(@($btnGo,$txtLog))

function Write-Log($msg){
    $ts = (Get-Date -f HH:mm:ss)
    $txtLog.AppendText("$ts  $msg`r`n")
}

# --------------------------- actions --------------------------------------
$btnGo.Add_Click({

    $ErrorActionPreference = 'Stop'

    try{
        # vérifs
        $src = $txtSrcHost.Text.Trim(); $dst = $txtDstHost.Text.Trim()
        $uS  = $txtSrcUser.Text.Trim();  $uD  = $txtDstUser.Text.Trim()
        if(!$src -or !$dst -or !$uS -or !$uD){
            [Windows.Forms.MessageBox]::Show(
              'Tous les champs hôtes et utilisateurs sont obligatoires.',
              'Champ manquant',[Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $key = $txtKey.Text.Trim()
        # helpers pour ssh / scp
        function Get-SshArgs([string[]]$extra){
            $arr = @()
            if($key){ $arr += @('-i',$key) }
            $arr += $extra
            return ,$arr   # virgule = force tableau
        }

        ## 1/4  lance le backup
        Write-Log '>> 1/4  Lance le backup …'
        $cmdBackup = 'curl -sL https://raw.githubusercontent.com/BBR-ENERGIE/PublicHostConf/main/backup_grafana.sh | sudo bash -'
        & ssh (Get-SshArgs @("$uS@$src",$cmdBackup)) | Out-Null
        Write-Log 'Backup terminé.'

        ## 2/4  récupère dossier
        $localTmp = 'C:\Temp\grafana_backup'
        if(Test-Path $localTmp){ Remove-Item $localTmp -Recurse -Force }
        New-Item -ItemType Directory -Path $localTmp | Out-Null

        Write-Log '>> 2/4  Récupère le dossier …'
        $remoteSrc = "${uS}@${src}:/root/grafana/backup"
        & scp (Get-SshArgs @('-r',$remoteSrc,$localTmp)) | Out-Null
        Write-Log "Dossier reçu dans $localTmp."

        ## 3/4  envoie vers la cible
        Write-Log '>> 3/4  Envoie le dossier vers la cible …'
        & ssh (Get-SshArgs @("$uD@$dst",'sudo mkdir -p /root/grafana/backup')) | Out-Null
        $remoteDst = "${uD}@${dst}:/root/grafana/"
        & scp (Get-SshArgs @('-r',"$localTmp\backup",$remoteDst)) | Out-Null
        Write-Log 'Dossier transféré.'

        ## 4/4  exécute script de restauration
        Write-Log '>> 4/4  Lance la restauration …'
        $cmdRestore = 'curl -sL https://raw.githubusercontent.com/BBR-ENERGIE/PublicHostConf/main/change_db_grafana.sh | sudo bash -'
        & ssh (Get-SshArgs @("$uD@$dst",$cmdRestore)) | Out-Null
        Write-Log 'Restauration terminée ✅'

        [Windows.Forms.MessageBox]::Show('Opération terminée !','Succès',
            [Windows.Forms.MessageBoxIcon]::Information)
    }
    catch{
        Write-Log "ERREUR : $_"
        [Windows.Forms.MessageBox]::Show("Une erreur est survenue.`r`n$_",
            'Erreur',[Windows.Forms.MessageBoxIcon]::Error)
    }
})

# ---------------------------- GO ------------------------------------------
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
