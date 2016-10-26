# Simple admiral stats exporter from kancolle-arcade.net for Windows PowerShell
# �v���O�����|�āF KOIZUMI Naoki (@sophiarcp)

$api_base = "https://kancolle-arcade.net/ac/api/"
$ymdhms = get-date -Format "yyyyMMdd_HHmmss"
$outdir = ".\json\" + $ymdhms
$credential_path = ".\cred.xml"

if ( -not(Test-Path $credential_path )) {
    try {
        Get-Credential -Message "������s�̂��߃v���C���[�Y�T�C�g�̔F�؏���o�^���Ă��������B" | Export-Clixml $credential_path | Out-Null
    } catch {
        exit 4
    }
    echo "$credential_path �ɕۑ����܂����B"
}

$credential = Import-Clixml $credential_path
$username = $credential.UserName
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password))

$err = 0

$headers = @{ "Referer" = "https://kancolle-arcade.net/ac/"; "X-Requested-With" = "XMLHttpRequest" ; "Host" = "kancolle-arcade.net" }
$bodytext = '{"id":"' + $username + '","password":"' + $pass + '"}'

try {
    $res = Invoke-RestMethod -uri "https://kancolle-arcade.net/ac/api/Auth/login" -Method Post -Body $bodytext -ContentType 'application/json' -Headers $headers -SessionVariable sv
    
    if (-not($res.login)) {
        echo "�F�؂Ɏ��s���܂����B���[�U�[���܂��̓p�X���[�h���Ԉ���Ă��܂��B"
        echo "�p�X���[�h�̓o�^���ԈႦ���ꍇ�́A $credential_path ���폜���čĎ��s���Ă��������B"
        exit 1
    }
} catch {
    echo "�F�؂Ɏ��s���܂����B�v���C���[�Y�T�C�g����~���Ă��邩�A�����e�i���X��(2:00�`7:00)�ł��B"
    exit 2
}

New-Item $outdir -ItemType Directory -Force | Out-Null

try {
    $infoarray = @("Personal/basicInfo", 'Area/captureInfo', 'TcBook/info', 'EquipBook/info', 'Campaign/history', 'Campaign/info', 'Campaign/present', 'CharacterList/info', 'EquipList/info', 'Quest/info', 'Event/info')
    foreach( $infoaddr in $infoArray ) {
        $outfn = $outdir + "\" + $infoaddr.Replace("/", "_") + "_" + $ymdhms + ".json"
        $uri = $api_base + $infoaddr
        #Invoke-RestMethod -uri $uri -Method Get -Headers $headers -WebSession $sv | ConvertTo-Json -Compress | Out-File $outfn #Invoke-RestMethod 
        Invoke-WebRequest -Uri $uri -UseBasicParsing -WebSession $sv -Headers $headers -OutFile $outfn 
    }        
} catch {
    echo "�f�[�^�擾���ɃG���[���������܂����B�ΏۃA�h���X:  $uri"
    exit 3
}

echo "�f�[�^�擾���������܂����B"
echo "�ۑ���: $outdir"