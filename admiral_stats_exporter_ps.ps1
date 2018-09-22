# Simple admiral stats exporter from kancolle-arcade.net for Windows PowerShell
# �v���O�����|�āF KOIZUMI Naoki (@sophiarcp)

function putJson2AS ($json_dir, $access_token) {
    # Upload exported files to Admiral Stats
    # �߂�l:
    # 0 : ����I��
    # 1 : �C���|�[�g�Ώۃt�@�C���^�C�v�擾�G���[(401)
    # 2 : �C���|�[�g�Ώۃt�@�C���^�C�v�擾�G���[(���̑�)
    # 3 : �C���|�[�g���s���̃G���[(400,401)
    # 4 : �C���|�[�g���s���̃G���[(���̑�)

    # Admiral Stats Import URL
    $AS_IMPORT_URL = 'https://www.admiral-stats.com/api/v1/import'

    # User Agent for logging on www.admiral-stats.com
    $AS_HTTP_HEADER_UA = 'AdmiralStatsExporter-PS/1.15.0'

    # Set Authorization header
    $headers = @{ "Authorization" = ("Bearer", $access_token -join " ") }

    # Get currently importable file types
    try {
        $uri = "$AS_IMPORT_URL/file_types"
        $importable_file_types = Invoke-RestMethod -uri $uri -Method Get -Headers $headers -UserAgent $AS_HTTP_HEADER_UA -ErrorAction stop
        Write-host "Importable file types: $importable_file_types"
    } catch {
        switch ($error[0].Exception.Response.StatusCode.value__) {
            401 {
                Write-Host "ERROR: "$Error[0]
                return 1
            }
            default {
                Write-Host "ERROR: "$Error[0]
                return 2
            }
        }
    }

    foreach ($json_file in (Get-ChildItem "$json_dir\*.*" -include *.json)) {
        $dummy = $json_file.name -match "(.*)_(\d{8}_\d{6})\.json$"
        $file_type = $matches[1]
        $timestamp = $matches[2]
        if ( -not ($importable_file_types -contains $file_type) ) { continue }

        $json = get-content $json_file -Raw -encoding UTF8

        # ���� GetBytes() ���Ȃ��ƁAUTF-8 ���܂� Body�i��F�͖��ꗗ�̑����X���b�g�j��
        # UTF-8 �Ƃ��ĔF�����ꂸ�A���M���ɕ�����������
        # �Q�l�Fhttps://www.uramiraikan.net/Works/entry-2798.html
        $json = [System.Text.Encoding]::UTF8.GetBytes($json)

        $uri = "$AS_IMPORT_URL/$file_type/$timestamp"
        $res = ""
        try {
            $res = Invoke-WebRequest -uri $uri -UseBasicParsing -Method Post -Body $json -ContentType 'application/json' -UserAgent $AS_HTTP_HEADER_UA -Headers $headers
            
            switch -regex ($res.StatusCode) {
                "20[01]" {
                    $resJson = ConvertFrom-Json($res.content)
                    Write-Host $resjson.data.message"�i�t�@�C�����F"$json_file.name"�j"
                }
                default {
                    Write-Host "ERROR: $res.content"
                }
            }
        } catch {
            switch -regex ($error[0].Exception.Response.StatusCode.value__) {
                "40[01]" {
                    Write-host "ERROR: "$error[0]
                    return 3
                }
                default {
                    Write-host "ERROR: "$error[0]
                    return 4
                }
            }
        }
    }
    return 0
}


$api_base = "https://kancolle-arcade.net/ac/api/"
$ymdhms = get-date -Format "yyyyMMdd_HHmmss"
$outdir = ".\json\" + $ymdhms
$credential_path = ".\cred.xml"
$token_path = ".\token.dat"
$do_upload = $false

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

# Check whether to upload JSON files or not
if ( $args[0] -eq "--upload" ) { 
    $do_upload = $true
    if ( Test-Path $token_path ) {
        $access_token = Get-Content $token_path -Encoding ascii
    } else {
        try {
            $access_token = Read-Host "������s�̂���Admiral Stats��API�g�[�N������͂��Ă��������B"
            if ( $access_token -ne "" ) {
                $access_token | out-file $token_path -Encoding ascii #| Out-Null
            } else {
                Write-Host "�g�[�N����񂪓��͂���Ă��܂���B�����𒆒f���܂��B"
                exit 4
            }
        } catch { 
            Write-Host $error[0]
            Write-Host "�g�[�N�����̎擾/�ۑ����ɃG���[���������܂����B�����𒆒f���܂��B"
            exit 5
        }
        echo "$token_path �ɕۑ����܂����B"
     }
}

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
    $infoarray = @("Personal/basicInfo", 'Area/captureInfo', 'TcBook/info', 'EquipBook/info', 'Campaign/history', 'Campaign/info', 'Campaign/present', 'CharacterList/info', 'EquipList/info', 'Quest/info', 'Event/info', 'RoomItemList/info', 'BlueprintList/info', 'Exercise/info', 'Cop/info')
    foreach( $infoaddr in $infoArray ) {
        $outfn = $outdir + "\" + $infoaddr.Replace("/", "_") + "_" + $ymdhms + ".json"
        $uri = $api_base + $infoaddr
        #Invoke-RestMethod -uri $uri -Method Get -Headers $headers -WebSession $sv | ConvertTo-Json -Compress | Out-File $outfn #Invoke-RestMethod 
        Invoke-WebRequest -Uri $uri -UseBasicParsing -WebSession $sv -Headers $headers -OutFile $outfn 

        # 204 (No Content) ���Ԃ��ꂽ�ꍇ�̓t�@�C���T�C�Y����ɂȂ�B���̏ꍇ�̓t�@�C�����폜����
        # Invoke-WebRequest �ɂ́A����I�����̃X�e�[�^�X�R�[�h���擾������@���Ȃ��������߁A�t�@�C���T�C�Y�Ŕ��f
        if ((Get-ChildItem $outfn).Length -eq 0) {
            echo "�_�E�����[�h�����t�@�C������̂��߁A�폜���܂��B�Ώۃt�@�C��: $outfn"
            Remove-Item $outfn
        }
    }
} catch {
    echo "�f�[�^�擾���ɃG���[���������܂����B�ΏۃA�h���X:  $uri"
    exit 3
}

echo "�f�[�^�擾���������܂����B"
echo "�ۑ���: $outdir"

# Upload exported files to Admiral Stats
if ($do_upload) {
    $ret = putJson2AS $outdir $access_token
    switch ($ret) {
        {1,3 -contains $_ } {
            Write-Host "API�g�[�N�����������Ȃ��\��������܂��B$token_path ���C�����邩�A�폜���čēo�^���Ă��������B"
        }
    }
}
