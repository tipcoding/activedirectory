# 06 — Groups (nhóm)

## Hai loại nhóm theo chức năng
| Loại | Có SID? | Dùng để |
|------|---------|---------|
| **Security group** | ✅ | cấp quyền (ACL), là security principal |
| **Distribution group** | ❌ (không cấp quyền) | danh sách phân phối email |

> Chỉ **security group** mới xuất hiện trong token/ACL và liên quan tấn công.

---

## Group scope (phạm vi nhóm) — khái niệm hay nhầm
Ba scope quyết định **ai được là thành viên** và **cấp quyền ở đâu**:

| Scope | Thành viên có thể từ | Cấp quyền được ở | Replicate vào GC |
|-------|----------------------|------------------|------------------|
| **Domain Local** | bất kỳ domain/forest tin cậy | **chỉ trong domain mình** | không (chỉ domain) |
| **Global** | **chỉ trong domain mình** | bất kỳ domain trong forest | member không, bản thân có |
| **Universal** | bất kỳ domain trong forest | bất kỳ domain trong forest | ✅ (có member) |

**Chi tiết:** Universal group được lưu trong GC (kèm member) → thay đổi member
universal gây replicate GC toàn forest. Enterprise Admins & Schema Admins là
Universal (ở root). Domain Admins là Global.

*Tài liệu:* [Group scope](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-groups).

---

## Nesting (lồng nhóm) & token
**Định nghĩa:** nhóm là thành viên của nhóm khác → quyền **thừa kế bắc cầu**.

**Chi tiết:** khi đăng nhập, Windows dựng **access token** chứa SID của user +
SID **mọi nhóm** user thuộc (kể cả gián tiếp qua nesting). Thêm user vào nhóm →
**phải lấy token mới** (logoff/login, hoặc TGT mới) thì quyền mới có hiệu lực.

*Ví dụ:* `alice ∈ Helpdesk ∈ IT Admins ∈ Administrators` → alice là admin dù
không trực tiếp trong Administrators.

---

## Mô hình AGDLP (Microsoft best practice)
**Định nghĩa:** **A**ccounts → **G**lobal group → **D**omain **L**ocal group →
**P**ermission. (Biến thể AGUDLP khi có universal.)

**Chi tiết:** user cho vào Global group (theo vai trò), Global group cho vào
Domain Local group (theo tài nguyên), gán quyền cho Domain Local group. Giúp
quản trị gọn. Hiểu mô hình này giúp lần ngược chuỗi nhóm khi phân tích BloodHound.

*Tài liệu:* [AGDLP](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/implementing-least-privilege-administrative-models).

---

## Built-in & nhóm đặc quyền (quan trọng cho tấn công/phòng thủ)
| Nhóm | Khả năng (tại sao nguy hiểm) |
|------|------------------------------|
| **Domain Admins** (512) | toàn quyền domain |
| **Enterprise Admins** (519) | toàn quyền forest |
| **Schema Admins** (518) | sửa schema forest |
| **Administrators** (S-1-5-32-544) | admin trên DC/máy |
| **Account Operators** (548) | tạo/sửa hầu hết user/group (trừ nhóm được bảo vệ) |
| **Server Operators** (549) | quản service trên DC → đổi binPath → SYSTEM |
| **Backup Operators** (551) | `SeBackup`/`SeRestore` → đọc NTDS.dit/SAM |
| **Print Operators** (550) | `SeLoadDriver` trên DC |
| **DnsAdmins** | nạp DLL vào dịch vụ DNS (SYSTEM trên DC) |
| **Remote Desktop Users** | RDP vào máy |
| **Remote Management Users** | WinRM (evil-winrm) |
| **Exchange Windows Permissions** | thường có WriteDacl trên domain → DCSync |
| **DnsAdmins / Cert Publishers / Group Policy Creator Owners** | các quyền gián tiếp dẫn tới leo thang |
| **Protected Users** (525) | *bảo vệ*: cấm NTLM/delegation cho thành viên (xem [file 15](15-mo-hinh-bao-mat-tiering.md)) |

Khai thác các nhóm này: [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md),
[OSCP-AD/04](../OSCP-AD/04-leo-thang-acl-delegation.md).

---

## Primary group
**Định nghĩa:** nhóm "chính" của user (`primaryGroupID`, mặc định 513 = Domain
Users). Khác thành viên thường — **không hiển thị trong `memberOf`** → dễ bị bỏ
sót khi liệt kê (thủ thuật ẩn mình: đặt Domain Admins làm primary group).

*Ví dụ:* `primaryGroupID = 512` nghĩa là user thuộc Domain Admins qua primary group.

---

## Thực hành liệt kê nhóm
```bash
net group "Domain Admins" /domain
nxc ldap 10.10.10.100 -u alice -p 'Password123!' --groups
```
```powershell
Get-DomainGroupMember "Domain Admins" -Recurse        # PowerView (gồm nesting)
Get-ADGroupMember "Domain Admins" -Recursive
```
```cypher
MATCH (u:User)-[:MemberOf*1..]->(g:Group {name:"DOMAIN ADMINS@CORP.LOCAL"}) RETURN u   // BloodHound nesting
```
