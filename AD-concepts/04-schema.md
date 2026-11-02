# 04 — Schema

## Schema
**Định nghĩa:** "bản thiết kế" của directory — định nghĩa **mọi loại object
(class)** và **mọi thuộc tính (attribute)** có thể tồn tại.

**Chi tiết:** Schema nằm trong **Schema NC** (`CN=Schema,CN=Configuration,
DC=corp,DC=local`), chung cho **toàn forest** (một forest = một schema). Mở rộng
schema (vd cài Exchange) là thay đổi lớn, không hoàn tác dễ, do **Schema Master**
(1 trong 5 FSMO) quản lý.

*Tài liệu:* [AD Schema](https://learn.microsoft.com/windows/win32/adschema/active-directory-schema),
[[MS-ADSC] Schema Classes](https://learn.microsoft.com/openspecs/windows_protocols/ms-adsc/).

---

## Class (classSchema)
**Định nghĩa:** khuôn mẫu cho một loại object (user, computer, group, GPO…).

**Chi tiết:** class có **mandatory attributes** (`mustContain`) và **optional**
(`mayContain`), và kế thừa từ class cha (`subClassOf`). Mỗi object khai báo class
qua thuộc tính **objectClass** (dạng danh sách, từ gốc `top` xuống).

*Ví dụ:* object user có `objectClass: top; person; organizationalPerson; user`.
→ cho thấy chuỗi kế thừa.

---

## Attribute (attributeSchema)
**Định nghĩa:** một thuộc tính (field) có thể gán cho object, ví dụ
`sAMAccountName`, `description`, `servicePrincipalName`, `memberOf`.

**Chi tiết thuộc tính của attribute:**
- **lDAPDisplayName** — tên dùng trong LDAP (vd `sAMAccountName`).
- **attributeSyntax / oMSyntax** — kiểu dữ liệu (string, int, SID, DN…).
- **isSingleValued** — đơn trị hay đa trị (vd `servicePrincipalName` đa trị).
- **systemFlags / searchFlags** — ví dụ cờ **CONFIDENTIAL** (cần quyền đặc biệt
  để đọc — vd LAPS `ms-Mcs-AdmPwd`), hoặc **được sao chép vào GC** (partial
  attribute set).

*Ví dụ attribute quan trọng khi tấn công:*
| Attribute | Ý nghĩa |
|-----------|---------|
| `userAccountControl` | cờ tài khoản (disabled, no-preauth, trusted-for-delegation…) |
| `servicePrincipalName` | SPN → kerberoast |
| `msDS-AllowedToDelegateTo` | constrained delegation |
| `msDS-AllowedToActOnBehalfOfOtherIdentity` | RBCD |
| `msDS-KeyCredentialLink` | shadow credentials |
| `ms-Mcs-AdmPwd` / `msLAPS-Password` | mật khẩu LAPS |
| `msDS-ManagedPassword` | mật khẩu gMSA |
| `adminCount` | =1 nếu được SDProp bảo vệ ([file 15](15-mo-hinh-bao-mat-tiering.md)) |

*Tài liệu:* [All Attributes](https://learn.microsoft.com/windows/win32/adschema/attributes-all).

---

## objectClass vs objectCategory
- **objectClass** — đa trị, toàn chuỗi kế thừa (`top;person;...;user`).
- **objectCategory** — đơn trị, class "chính" → lọc LDAP nhanh hơn
  (`(objectCategory=person)`).

*Ví dụ filter:* `(&(objectCategory=computer)(operatingSystem=*Server*))`.

---

## userAccountControl (UAC flags) — rất quan trọng
**Định nghĩa:** một bitmask trên user/computer điều khiển trạng thái & hành vi.

**Chi tiết các bit hay gặp:**
| Giá trị (hex/dec) | Cờ | Ý nghĩa tấn công |
|-------------------|-----|------------------|
| `0x2` (2) | ACCOUNTDISABLE | tài khoản bị tắt |
| `0x20` (32) | PASSWD_NOTREQD | cho phép mật khẩu rỗng |
| `0x200` (512) | NORMAL_ACCOUNT | user thường |
| `0x1000` (4096) | WORKSTATION_TRUST | tài khoản máy |
| `0x10000` (65536) | DONT_EXPIRE_PASSWORD | pass không hết hạn |
| `0x80000` (524288) | TRUSTED_FOR_DELEGATION | **unconstrained delegation** |
| `0x400000` (4194304) | DONT_REQ_PREAUTH | **AS-REP roastable** |
| `0x1000000` (16777216) | TRUSTED_TO_AUTH_FOR_DELEGATION | **constrained delegation (protocol transition)** |

*Ví dụ LDAP tìm AS-REP roastable:*
```
(userAccountControl:1.2.840.113556.1.4.803:=4194304)
```
(`1.2.840.113556.1.4.803` = toán tử bitwise-AND của AD.)

*Tài liệu:* [userAccountControl flags](https://learn.microsoft.com/troubleshoot/windows-server/identity/useraccountcontrol-manipulate-account-properties).

---

## Enumerate schema (thực hành)
```powershell
# Lớp và thuộc tính
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -Filter * -Properties lDAPDisplayName
setspn -T corp.local -Q */*            # liệt kê SPN toàn domain
```
```bash
ldapsearch -x -H ldap://10.10.10.100 -b "CN=Schema,CN=Configuration,DC=corp,DC=local" "(objectClass=attributeSchema)" lDAPDisplayName
```
