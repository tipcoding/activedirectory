# 01 — Directory Service & LDAP

## Directory Service (dịch vụ thư mục)
**Định nghĩa:** cơ sở dữ liệu phân cấp, tối ưu cho **đọc nhiều hơn ghi**, lưu
thông tin về tài nguyên mạng (user, máy, nhóm, chính sách) và cho phép tra cứu,
xác thực, phân quyền tập trung.

**Chi tiết:** Active Directory Domain Services (AD DS) là triển khai directory
service của Microsoft, dựa trên chuẩn **X.500** (mô hình thư mục) và truy cập qua
**LDAP**. Dữ liệu tổ chức thành cây — **DIT (Directory Information Tree)**.

*Ví dụ:* thay vì mỗi máy có user riêng, một domain lưu user tập trung; đăng nhập
máy nào trong domain cũng dùng cùng tài khoản.

*Tài liệu gốc:* [AD DS Overview](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview).

---

## X.500 & DIT
**Định nghĩa:** X.500 là bộ chuẩn ISO cho directory; **DIT** là cây chứa toàn bộ
object theo phân cấp.

**Chi tiết:** AD mượn mô hình đặt tên phân cấp của X.500 (DN, RDN) nhưng dùng
LDAP (nhẹ hơn DAP của X.500). Gốc cây là naming context của domain
(`DC=corp,DC=local`).

*Tài liệu:* [RFC 4512 — LDAP Directory Information Models](https://www.rfc-editor.org/rfc/rfc4512).

---

## LDAP (Lightweight Directory Access Protocol)
**Định nghĩa:** giao thức truy vấn/sửa đổi directory, chạy trên **TCP 389**
(LDAP) và **636** (LDAPS/TLS); **3268/3269** cho Global Catalog.

**Chi tiết — các thao tác LDAP:**
- **bind** — xác thực tới directory (anonymous, simple = user+pass, hoặc SASL/GSSAPI = Kerberos).
- **search** — truy vấn với *base DN* + *scope* (base/one/sub) + *filter*.
- **add / modify / delete / modifyDN** — thay đổi object.
- **LDAP filter** dùng cú pháp ngoặc: `(&(objectClass=user)(sAMAccountName=alice))`.

*Ví dụ truy vấn:*
```bash
# rootDSE (luôn đọc được, kể cả chưa xác thực) → lấy naming context
ldapsearch -x -H ldap://10.10.10.100 -s base namingcontexts
# Tìm user alice (có bind)
ldapsearch -x -H ldap://10.10.10.100 -D "alice@corp.local" -w 'Password123!' \
  -b "DC=corp,DC=local" "(&(objectClass=user)(sAMAccountName=alice))"
```
Filter phổ biến: `(objectClass=user)`, `(servicePrincipalName=*)` (kerberoastable),
`(userAccountControl:1.2.840.113556.1.4.803:=4194304)` (ASREP — không pre-auth).

*Tài liệu gốc:* [RFC 4511 — LDAP Protocol](https://www.rfc-editor.org/rfc/rfc4511),
[Search Filters RFC 4515](https://www.rfc-editor.org/rfc/rfc4515).

---

## rootDSE
**Định nghĩa:** entry "gốc" đặc biệt (DN rỗng) mô tả server LDAP: naming context,
domain functional level, DC name…

**Chi tiết:** đọc được **không cần xác thực** → bước recon đầu tiên để biết tên
domain (`defaultNamingContext`), `dnsHostName`, `supportedSASLMechanisms`.

*Ví dụ:*
```bash
ldapsearch -x -H ldap://10.10.10.100 -s base '(objectClass=*)'
# defaultNamingContext: DC=corp,DC=local
# dnsHostName: DC01.corp.local
```

---

## LDAPS & Channel Binding / Signing
**Định nghĩa:** LDAPS = LDAP over TLS (636). **LDAP signing** và **channel
binding** là biện pháp chống **NTLM relay** tới LDAP.

**Chi tiết:** nếu DC *không* bắt buộc signing/channel binding (mặc định lịch sử),
kẻ tấn công relay NTLM sang LDAP để tạo máy/RBCD (xem
[mindmaps/14](../mindmaps/AD-2025.03/14-ntlm-relay.md)).

*Tài liệu:* [Microsoft ADV190023 — LDAP channel binding & signing](https://support.microsoft.com/help/4520412).

---

## ADSI & ADWS
- **ADSI (Active Directory Service Interfaces):** API/COM để thao tác AD từ
  script/PowerShell. *Ví dụ:* `([adsisearcher]"(samaccountname=alice)").FindAll()`.
- **ADWS (AD Web Services), cổng 9389:** dịch vụ SOAP mà module PowerShell
  `ActiveDirectory` và tool như **SOAPHound** dùng; truy vấn qua ADWS **ít bị
  luật phát hiện LDAP** bắt hơn.

*Tài liệu:* [ADSI](https://learn.microsoft.com/windows/win32/adsi/active-directory-service-interfaces-adsi),
[[MS-ADDM] ADWS](https://learn.microsoft.com/openspecs/windows_protocols/ms-adcap/).

---

## Naming Context (Partition)
**Định nghĩa:** một "phần" của DIT được replicate độc lập. Ba NC mặc định:
- **Domain NC** — `DC=corp,DC=local` (user, máy, nhóm…).
- **Configuration NC** — `CN=Configuration,DC=corp,DC=local` (site, service, topology).
- **Schema NC** — `CN=Schema,CN=Configuration,...` (định nghĩa class/attribute).
- *(tùy chọn)* **Application partitions** — ví dụ DNS (`DomainDnsZones`, `ForestDnsZones`).

Chi tiết replication & phạm vi: [file 12](12-replication-va-fsmo.md).

*Tài liệu:* [[MS-ADTS] §3.1.1.1 Directory partitions](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/).
