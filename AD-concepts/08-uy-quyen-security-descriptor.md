# 08 — Ủy quyền: Access Token, Security Descriptor, ACL/ACE

Xác thực = "bạn là ai"; **ủy quyền** = "bạn được làm gì". Phần này giải thích mô
hình phân quyền của Windows/AD.

---

## Access Token
**Định nghĩa:** cấu trúc Windows gắn vào mỗi process/thread, chứa **SID user +
SID các nhóm + danh sách privileges + integrity level**.

**Chi tiết:** khi truy cập tài nguyên, Windows so token với **security
descriptor** của tài nguyên. Token dựng lúc đăng nhập → thêm nhóm phải lấy token
mới. **Impersonation token** cho phép service "mượn" danh tính client (nền tảng
của SeImpersonate/Potato).

*Ví dụ:* `whoami /all` in SID user, nhóm, và privileges của token hiện tại.

*Tài liệu:* [Access Tokens](https://learn.microsoft.com/windows/win32/secauthz/access-tokens).

---

## SID & RID
→ Đã giải thích ở [file 02 §SID](02-cau-truc-logic.md). Tóm tắt: SID định danh
principal cho phân quyền; RID là phần cuối (500=Administrator, 512=Domain Admins…).

### Well-known SIDs (cần nhớ)
| SID | Ý nghĩa |
|-----|---------|
| `S-1-0-0` | Nobody |
| `S-1-1-0` | Everyone |
| `S-1-5-7` | Anonymous |
| `S-1-5-11` | Authenticated Users |
| `S-1-5-18` | Local SYSTEM |
| `S-1-5-19 / -20` | Local/Network Service |
| `S-1-5-32-544` | Builtin\Administrators |
| `S-1-5-32-545` | Builtin\Users |
| `S-1-5-21-<domain>-512` | Domain Admins |
| `S-1-5-21-<root>-519` | Enterprise Admins |

*Tài liệu gốc:* [Well-known SIDs](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).

---

## Security Descriptor (SD)
**Định nghĩa:** cấu trúc gắn vào mỗi **securable object** (file, object AD, khóa
registry…), gồm:
- **Owner SID** — chủ sở hữu (owner luôn có quyền sửa DACL!).
- **Group SID** — (ít dùng, POSIX legacy).
- **DACL (Discretionary ACL)** — danh sách ACE "ai được/không được làm gì".
- **SACL (System ACL)** — ACE kiểm toán (audit) + mandatory integrity label.

**Chi tiết:** biểu diễn text bằng **SDDL**. Owner có quyền ngầm sửa DACL → kỹ
thuật **WriteOwner → WriteDacl → GenericAll**.

*Tài liệu gốc:* [[MS-DTYP] Security Descriptor](https://learn.microsoft.com/openspecs/windows_protocols/ms-dtyp/),
[SDDL](https://learn.microsoft.com/windows/win32/secauthz/security-descriptor-string-format).

---

## ACE (Access Control Entry)
**Định nghĩa:** một mục trong DACL: *principal (SID)* + *quyền (access mask)* +
*loại (allow/deny)* + *(với AD) object type GUID* + *cờ thừa kế*.

**Chi tiết — các quyền trên object AD hay bị lạm dụng:**
| Quyền | Hệ quả |
|-------|--------|
| **GenericAll** | toàn quyền → đổi pass / shadow cred / RBCD / add member |
| **GenericWrite** | ghi hầu hết thuộc tính → SPN (kerberoast), KeyCredentialLink (shadow cred), RBCD |
| **WriteDacl** | tự thêm ACE GenericAll cho mình |
| **WriteOwner** | đổi owner = mình → WriteDacl |
| **WriteProperty** (cụ thể) | ghi 1 thuộc tính (vd `member`, `servicePrincipalName`) |
| **Self / AddSelf** | tự thêm vào nhóm |
| **AllExtendedRights** | gồm ForceChangePassword, **DS-Replication (DCSync)**, đọc LAPS |
| **ExtendedRight: User-Force-Change-Password** | đặt mật khẩu không cần pass cũ |
| **ExtendedRight: DS-Replication-Get-Changes(-All)** | **DCSync** |

**Object-specific ACE:** trên AD, ACE có thể giới hạn vào **một thuộc tính/loại**
qua GUID (vд chỉ ghi `member`). BloodHound phân giải GUID để hiển thị edge đúng.

Khai thác từng ACE: [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md).

*Ví dụ đọc ACL:*
```powershell
Get-DomainObjectAcl -Identity "Domain Admins" -ResolveGUIDs | ? {$_.ActiveDirectoryRights -match "GenericAll|WriteDacl|WriteOwner"}
```
```bash
dacledit.py -action read -target "Domain Admins" corp.local/alice:'Password123!'
```

---

## Access Mask & thừa kế (inheritance)
- **Access mask:** bitmask quyền (Read, Write, Delete, và các quyền AD cụ thể).
- **Inheritance:** ACE trên container/OU có cờ để **lan xuống object con**
  (`CONTAINER_INHERIT`, `OBJECT_INHERIT`). Vì vậy quyền trên OU = quyền trên mọi
  object trong OU.

---

## Rights vs Permissions vs Privileges
- **Permission (quyền trên object):** gắn với 1 tài nguyên qua DACL (vd đọc file).
- **User right / Privilege (đặc quyền hệ thống):** quyền toàn máy, gán qua Group
  Policy / Local Security Policy, hiện trong token.

**Privileges đáng chú ý (local):**
| Privilege | Hệ quả |
|-----------|--------|
| `SeImpersonatePrivilege` | mạo danh token → Potato → SYSTEM |
| `SeDebugPrivilege` | đọc bộ nhớ process khác → dump LSASS |
| `SeBackupPrivilege` / `SeRestorePrivilege` | đọc/ghi mọi file → copy NTDS.dit/SAM |
| `SeTakeOwnershipPrivilege` | chiếm owner object |
| `SeLoadDriverPrivilege` | nạp driver → privesc |
| `SeTcbPrivilege` | "act as part of OS" |

*Ví dụ:* `whoami /priv` → nếu thấy `SeImpersonatePrivilege Enabled` → GodPotato/
PrintSpoofer ([mindmaps/04](../mindmaps/AD-2025.03/04-low-access-privesc.md)).

*Tài liệu:* [Privileges](https://learn.microsoft.com/windows/win32/secauthz/privilege-constants).

---

## DCSync rights (ứng dụng trực tiếp)
Principal có **DS-Replication-Get-Changes** + **-Get-Changes-All** trên domain
object → giả DC xin hash (DCSync). Thường là DC/DA, nhưng **cấu hình sai** (vd
Exchange Windows Permissions) gán cho user thường → leo thẳng. Xem
[mindmaps/12](../mindmaps/AD-2025.03/12-domain-admin-persistence.md).
