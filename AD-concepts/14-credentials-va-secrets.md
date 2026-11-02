# 14 — Credentials & Secrets (nơi lưu & dạng bí mật)

Hiểu "mật khẩu/hash nằm ở đâu, dạng gì" để biết lấy được gì khi chiếm một máy.

---

## NT hash
**Định nghĩa:** `MD4(UTF-16LE(password))`, 32 hex. Dùng cho NTLM và Kerberos RC4.

**Chi tiết:** **không salt** → PtH được; crack `hashcat -m 1000`. Lưu trong SAM
(local) và NTDS.dit (domain).

*Ví dụ:* `2b576acbe6bcfda7294d6bd18041b8fe`.

---

## LM hash (cũ)
**Định nghĩa:** hash rất yếu thời cũ; mặc định **tắt** từ Vista/2008. Nếu thấy
`aad3b435b51404eeaad3b435b51404ee` nghĩa là **LM rỗng** (không dùng).

---

## SAM (Security Account Manager)
**Định nghĩa:** database hash **tài khoản local** của một máy
(`HKLM\SAM`, file `C:\Windows\System32\config\SAM`), giải mã bằng **SYSTEM** hive
(bootkey).

**Chi tiết:** hash local Administrator thường **dùng lại** nhiều máy → PtH lan rộng.

*Ví dụ:*
```bash
secretsdump.py -sam SAM -system SYSTEM LOCAL
nxc smb 10.10.10.0/24 -u alice -p 'pass' --sam
```

---

## LSA Secrets
**Định nghĩa:** kho bí mật của LSA trong registry (`HKLM\SECURITY\Policy\Secrets`)
— mật khẩu service, autologon, mật khẩu tài khoản máy, cached creds…

*Ví dụ:*
```bash
secretsdump.py -security SECURITY -system SYSTEM LOCAL
nxc smb <ip> -u alice -p 'pass' --lsa
```

---

## LSASS (Local Security Authority Subsystem Service)
**Định nghĩa:** tiến trình giữ **credential của phiên đăng nhập đang hoạt động**
trong bộ nhớ: NT hash, **ticket Kerberos**, đôi khi plaintext (WDigest cũ), DPAPI
keys.

**Chi tiết:** dump LSASS (mimikatz/procdump/comsvcs) → lấy creds user khác đang
login. **Credential Guard** (VBS) và **PPL** bảo vệ LSASS → cần bypass.

*Ví dụ:*
```powershell
rundll32 comsvcs.dll, MiniDump <lsass_pid> C:\Temp\lsass.dmp full
```
```bash
pypykatz lsa minidump lsass.dmp
```

---

## Kerberos keys & tickets
- **Khóa Kerberos:** RC4 (=NT hash) và AES128/256 (có salt). `sekurlsa::ekeys`.
- **Ticket trong LSASS:** TGT/TGS của phiên → export để Pass-the-Ticket.

---

## NTDS.dit (domain)
**Định nghĩa:** database AD trên DC, chứa **hash mọi tài khoản domain** +
`krbtgt`. Giải mã bằng SYSTEM hive (bootkey) + PEK.

*Ví dụ:*
```bash
secretsdump.py 'corp.local/alice:pass'@dc01 -just-dc           # DCSync (không cần lên DC)
secretsdump.py -ntds ntds.dit -system SYSTEM LOCAL             # offline
```

---

## krbtgt
**Định nghĩa:** khóa ký TGT của domain. Hash krbtgt → **Golden Ticket**.
→ [file 07](07-xac-thuc-kerberos-ntlm.md), [file 05 objects](05-objects-security-principals.md).

---

## Cached domain credentials (DCC2 / MSCache2)
**Định nghĩa:** hash để đăng nhập domain **khi DC offline**, lưu trong LSA
secrets. Dạng `$DCC2$...`.

**Chi tiết:** **không PtH được**, chỉ crack offline (`hashcat -m 2100`, chậm).

---

## DPAPI (Data Protection API)
**Định nghĩa:** API Windows mã hoá bí mật người dùng (mật khẩu trình duyệt, Wi-Fi,
Credential Manager, RDP, vault) bằng **masterkey** dẫn xuất từ mật khẩu user (và
có **domain backup key** ở DC).

**Chi tiết:** admin/SYSTEM hoặc có masterkey → giải mã. **Domain DPAPI backup
key** (trên DC) giải mã DPAPI của **mọi** user trong domain.

*Ví dụ:*
```bash
donpapi collect -H :<hash> corp.local/alice@10.10.10.0/24
dploot.py browser -d corp.local -u alice -p 'pass' <ip>
```

*Tài liệu:* [DPAPI (The Hacker Recipes)](https://www.thehacker.recipes/ad/movement/credentials/dpapi).

---

## LAPS (Local Administrator Password Solution)
**Định nghĩa:** giải pháp đặt mật khẩu admin **local ngẫu nhiên, khác nhau mỗi
máy**, lưu trong thuộc tính máy: `ms-Mcs-AdmPwd` (LAPS v1, **confidential**) /
`msLAPS-Password` (Windows LAPS mới).

**Chi tiết:** chỉ principal được ủy quyền đọc (edge **ReadLAPSPassword**). Giải
quyết vấn đề "hash local admin dùng chung" → PtH không lan được nếu LAPS bật.

*Ví dụ:*
```bash
nxc ldap <dc> -u alice -p 'pass' -M laps
```

*Tài liệu:* [Windows LAPS](https://learn.microsoft.com/windows-server/identity/laps/laps-overview).

---

## gMSA password
**Định nghĩa:** blob `msDS-ManagedPassword` do AD quản; principal được phép tính
ra NT hash. → [file 05 §gMSA](05-objects-security-principals.md).

---

## Access Token (nhắc lại)
Không phải "secret" lưu trữ, nhưng là **danh tính runtime**; mạo danh token
(SeImpersonate) hoặc đánh cắp token là cách lateral/privesc. → [file 08](08-uy-quyen-security-descriptor.md).

---

## Bảng tổng: secret nào lấy ở đâu
| Secret | Nguồn | Quyền cần | PtH? |
|--------|-------|-----------|------|
| NT hash local | SAM | admin local | ✅ |
| NT hash domain | NTDS.dit / DCSync | DA / replication | ✅ |
| Creds phiên (hash/ticket/plain) | LSASS | admin/SYSTEM | ✅/PtT |
| Service/autologon/máy | LSA secrets | admin | tùy |
| DCC2 | LSA cache | admin | ❌ (crack) |
| DPAPI secrets | DPAPI vault | admin/masterkey | n/a |
| LAPS | thuộc tính máy | ReadLAPSPassword | dùng pass trực tiếp |
| gMSA | msDS-ManagedPassword | ReadGMSAPassword | ✅ |
