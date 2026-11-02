# 05 — Objects & Security Principals

**Security principal** = object có **SID** → có thể được cấp quyền (user, group,
computer, gMSA). Object không có SID (OU, GPO, contact) không phải security
principal.

---

## User account
**Định nghĩa:** đại diện một người dùng; có mật khẩu, SID, thuộc nhóm.

**Chi tiết thuộc tính:** `sAMAccountName`, `userPrincipalName`,
`userAccountControl`, `memberOf`, `description`, `servicePrincipalName` (nếu là
tài khoản dịch vụ), `pwdLastSet`, `lastLogon`, `adminCount`.

*Ví dụ:* `CN=Alice,OU=Finance,DC=corp,DC=local`, `sAMAccountName=alice`.

*Tài liệu:* [user class](https://learn.microsoft.com/windows/win32/adschema/c-user).

---

## Computer account
**Định nghĩa:** mỗi máy join domain có một tài khoản máy (`sAMAccountName` tận
cùng `$`, vd `WS01$`), là một **security principal**.

**Chi tiết:** máy có mật khẩu riêng (đổi tự động ~30 ngày), hash dùng cho
Kerberos (tài khoản máy có SPN như `HOST/ws01`, `cifs/ws01`). **Tài khoản máy có
quyền tương đương SYSTEM của máy đó** — chiếm được hash máy = quyền trên máy đó
(dùng trong RBCD, S4U). **MachineAccountQuota** (mặc định 10) cho phép user
thường tạo tài khoản máy → lạm dụng RBCD/Shadow cred.

*Ví dụ:*
```bash
nxc ldap 10.10.10.100 -u alice -p 'Password123!' -M maq   # xem MachineAccountQuota
```

---

## Group
→ Xem riêng [file 06](06-groups.md) (scope, nesting, built-in).

---

## Contact
**Định nghĩa:** object chứa thông tin liên hệ (thường user ngoài tổ chức, dùng
cho email). **Không có SID** → không đăng nhập/được cấp quyền.

---

## InetOrgPerson
**Định nghĩa:** class user tương thích chuẩn LDAP liên nền tảng (RFC 2798); hành
xử gần như user AD.

---

## Managed Service Account (MSA) & Group Managed Service Account (gMSA)
**Định nghĩa:** tài khoản dịch vụ mà **mật khẩu do AD tự quản** (tự đổi, không ai
biết plaintext).
- **sMSA (standalone):** gắn 1 máy.
- **gMSA:** dùng chung nhiều máy; mật khẩu lưu ở `msDS-ManagedPassword` (blob),
  chỉ principal trong `PrincipalsAllowedToRetrieveManagedPassword` đọc được.

**Chi tiết tấn công:** đọc được blob → tính NT hash → PtH. (Cần functional level
2012+.)

*Ví dụ:*
```bash
nxc ldap 10.10.10.100 -u alice -p 'Password123!' --gmsa
gMSADumper.py -u alice -p 'Password123!' -d corp.local
```

*Tài liệu:* [gMSA](https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview).

---

## foreignSecurityPrincipal (FSP)
**Định nghĩa:** object đại diện một principal từ **domain/forest khác** được thêm
vào nhóm của domain này. Hiển thị dưới `CN=ForeignSecurityPrincipals,DC=...`.

**Chi tiết:** giúp cấp quyền chéo domain qua trust. BloodHound dùng để vẽ đường
cross-domain (xem [file 11](11-trusts.md)).

*Ví dụ query:* `Get-DomainForeignGroupMember -Domain corp.local`.

---

## krbtgt account
**Định nghĩa:** tài khoản dịch vụ đặc biệt (RID 502) — **khóa ký của KDC**. Hash
của nó mã hoá mọi TGT trong domain.

**Chi tiết:** lấy được hash `krbtgt` → **Golden Ticket** (tự ký TGT bất kỳ). Đổi
mật khẩu krbtgt (2 lần) để vô hiệu golden ticket. Xem [file 07](07-xac-thuc-kerberos-ntlm.md)
& [file 14](14-credentials-va-secrets.md).

---

## Tài khoản/đối tượng đặc biệt mặc định
| Object | RID/vị trí | Ghi chú |
|--------|-----------|---------|
| Administrator | RID 500 | admin nội tại domain; không bị lock mặc định |
| Guest | RID 501 | thường disabled |
| krbtgt | RID 502 | khóa KDC |
| Domain Admins | RID 512 | admin domain |
| Domain Users | RID 513 | mọi user |
| Domain Computers | RID 515 | mọi máy |
| Domain Controllers | RID 516 | các DC |
| Enterprise Admins | RID 519 | admin toàn forest (ở root domain) |
| Schema Admins | RID 518 | sửa schema |

---

## Trạng thái & cờ (xem thêm UAC)
`userAccountControl` quyết định disabled / no-preauth / delegation… — chi tiết
[file 04 §UAC](04-schema.md).

*Ví dụ liệt kê user + cờ:*
```bash
ldapsearch -x -H ldap://10.10.10.100 -D alice@corp.local -w 'Password123!' \
  -b "DC=corp,DC=local" "(objectCategory=person)" sAMAccountName userAccountControl description
```
