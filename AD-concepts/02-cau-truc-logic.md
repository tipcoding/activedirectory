# 02 — Cấu trúc logic của Active Directory

## Forest (rừng)
**Định nghĩa:** ranh giới bảo mật **cao nhất** và đơn vị sao chép schema. Một
forest chứa ≥1 domain tin cậy lẫn nhau.

**Chi tiết:** mọi domain trong forest **chia sẻ chung Schema và Configuration NC**,
và tin cậy transitive hai chiều. **Forest = ranh giới bảo mật thật** (không phải
domain) — chiếm được một domain con thường dẫn tới chiếm forest root (xem
[file 11](11-trusts.md)). Forest root domain là domain tạo đầu tiên.

*Ví dụ:* forest `corp.local` chứa domain root `corp.local` và domain con
`dev.corp.local`, `sales.corp.local`.

*Tài liệu:* [Forests as security boundaries](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/understanding-active-directory-for-security-professionals).

---

## Tree (cây domain)
**Định nghĩa:** tập hợp domain chia sẻ **không gian tên DNS liền mạch**
(contiguous namespace).

*Ví dụ:* `corp.local` → `eu.corp.local` → `fr.eu.corp.local` là một tree. Một
forest có thể có **nhiều tree** với namespace khác nhau (ví dụ thêm
`contoso.com`), nối nhau bằng **tree-root trust**.

---

## Domain
**Định nghĩa:** đơn vị quản trị & sao chép chính; chứa object (user/máy/nhóm),
có chính sách mật khẩu riêng (mức domain), và ≥1 Domain Controller.

**Chi tiết:** domain = một **Domain NC** (partition). Có **domain functional
level** (2008R2/2012R2/2016…) quyết định tính năng khả dụng. Tên domain có 2
dạng: **DNS** (`corp.local`) và **NetBIOS** (`CORP`).

*Ví dụ:* `corp.local`, NetBIOS `CORP`; user đăng nhập `CORP\alice` hoặc
`alice@corp.local`.

*Tài liệu:* [Domains and forests](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/understanding-the-active-directory-logical-model).

---

## Organizational Unit (OU)
**Định nghĩa:** container để **nhóm object và áp Group Policy / ủy quyền quản trị**.

**Chi tiết:** OU khác với container thường ở chỗ **GPO link được vào OU** và có
thể **delegate control** (ủy quyền quản trị một phần). OU lồng nhau tạo phân cấp
tổ chức. Quyền trên OU **thừa kế** xuống object con → lạm dụng ACL trên OU rất
mạnh (xem [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md)).

*Ví dụ DN:* `OU=Finance,OU=Users,DC=corp,DC=local`.

---

## Object & Container
**Định nghĩa:** **Object** = một thực thể trong directory (user, computer, group,
GPO…), là instance của một **class** trong schema. **Container** = object chứa
object khác (ví dụ `CN=Users`, `CN=Computers` — là container mặc định, **không
link GPO được** như OU).

*Ví dụ:* `CN=Users,DC=corp,DC=local` (container mặc định chứa user),
`CN=Computers,DC=corp,DC=local`.

---

## Đặt tên (naming) — DN, RDN, CN, DC, OU
**Định nghĩa các thành phần của Distinguished Name (DN):**
- **DN (Distinguished Name):** đường dẫn đầy đủ, duy nhất tới object.
- **RDN (Relative DN):** thành phần trái nhất (tên trong container cha).
- **CN (Common Name):** tên hiển thị của object.
- **DC (Domain Component):** mảnh tên miền.
- **OU:** tổ chức đơn vị.

*Ví dụ:*
```
DN : CN=Alice Smith,OU=Finance,DC=corp,DC=local
RDN: CN=Alice Smith
các DC: DC=corp , DC=local  → domain corp.local
```

*Tài liệu:* [RFC 4514 — String Representation of DN](https://www.rfc-editor.org/rfc/rfc4514).

---

## Các tên định danh của một security principal
Một user/máy có nhiều "tên" khác nhau — hiểu rõ để tránh nhầm khi tấn công:

| Thuộc tính | Ví dụ | Dùng khi |
|-----------|-------|----------|
| **sAMAccountName** | `alice` (máy: `DC01$`) | đăng nhập kiểu cũ `CORP\alice`; NTLM |
| **userPrincipalName (UPN)** | `alice@corp.local` | đăng nhập hiện đại; Kerberos |
| **distinguishedName (DN)** | `CN=Alice,OU=Finance,DC=corp,DC=local` | LDAP |
| **objectGUID** | `a1b2c3d4-...` | định danh **không đổi** suốt đời object |
| **objectSID** | `S-1-5-21-...-1103` | phân quyền (ACL/token) |
| **CN** | `Alice Smith` | hiển thị |

> Tài khoản **máy** có `sAMAccountName` kết thúc bằng `$` (vd `DC01$`).

---

## GUID (objectGUID)
**Định nghĩa:** định danh 128-bit **duy nhất toàn cầu, bất biến** cho mỗi object.

**Chi tiết:** không đổi kể cả khi đổi tên/di chuyển object → dùng để tham chiếu
bền vững. Khác với SID (có thể khác giữa các domain).

*Ví dụ:* `objectGUID: 5f2e...-...-...`.

---

## SID (Security Identifier)
**Định nghĩa:** chuỗi định danh dùng cho **bảo mật** (phân quyền). Gồm *domain
SID* + *RID*.

**Chi tiết:**
```
S-1-5-21-3623811015-3361044348-30300820-1104
│ │ │  └──────── domain identifier ───────┘ └RID┘
│ │ └ authority (5 = NT Authority)
│ └ revision
└ "S" = SID
```
- **RID (Relative ID):** phần cuối, phân biệt principal trong domain. RID nổi
  tiếng: **500** = Administrator, **501** = Guest, **512** = Domain Admins,
  **513** = Domain Users, **519** = Enterprise Admins, **502** = krbtgt.
- **Well-known SID:** cố định mọi hệ thống, ví dụ `S-1-5-18` = Local SYSTEM,
  `S-1-1-0` = Everyone, `S-1-5-32-544` = Administrators (built-in).

*Ví dụ:* Domain Admins = `<domainSID>-512`; Enterprise Admins =
`<rootDomainSID>-519` (dùng trong SID history attack — [file 11](11-trusts.md)).

*Tài liệu gốc:* [Well-known SIDs](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers),
[[MS-DTYP] §2.4.2 SID](https://learn.microsoft.com/openspecs/windows_protocols/ms-dtyp/).

---

## Namespace & FQDN
**Định nghĩa:** không gian tên DNS của forest/domain. **FQDN** = tên đầy đủ gồm
hostname + domain.

*Ví dụ:* DC có FQDN `DC01.corp.local`; namespace forest = `corp.local`.
Kerberos **bắt buộc dùng FQDN** (không dùng IP) — xem [file 07](07-xac-thuc-kerberos-ntlm.md).
