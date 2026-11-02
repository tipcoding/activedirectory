# 10 — DNS trong Active Directory

## Vai trò của DNS
**Định nghĩa:** AD **phụ thuộc hoàn toàn DNS** để client tìm dịch vụ (DC,
Kerberos, LDAP, GC). Không có DNS đúng → không đăng nhập domain, Kerberos fail.

**Chi tiết:** AD dùng **SRV records** để công bố "dịch vụ X ở host nào, port
nào". DC thường kiêm DNS server.

*Tài liệu:* [DNS and AD DS](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/dns-and-ad-ds),
[RFC 2782 — DNS SRV](https://www.rfc-editor.org/rfc/rfc2782).

---

## SRV records quan trọng
| Bản ghi SRV | Công bố |
|-------------|---------|
| `_ldap._tcp.dc._msdcs.<domain>` | các **Domain Controller** |
| `_kerberos._tcp.<domain>` | KDC (Kerberos) |
| `_ldap._tcp.<site>._sites.dc._msdcs.<domain>` | DC theo **site** |
| `_gc._tcp.<domain>` | **Global Catalog** |
| `_kpasswd._tcp.<domain>` | đổi mật khẩu Kerberos (kpasswd 464) |

*Ví dụ tìm DC qua DNS:*
```bash
nslookup -type=SRV _ldap._tcp.dc._msdcs.corp.local 10.10.10.100
dig SRV _kerberos._tcp.corp.local @10.10.10.100
```

---

## Vùng `_msdcs`
**Định nghĩa:** zone con `_msdcs.<forest_root>` chứa bản ghi đặc thù Microsoft
(định danh DC bằng GUID, vai trò GC, PDC). Quan trọng cho replication & locator.

---

## AD-Integrated Zone
**Định nghĩa:** zone DNS lưu **trong AD** (application partition
`DomainDnsZones` / `ForestDnsZones`) thay vì file text.

**Chi tiết lợi ích:** replicate theo AD (multi-master), bảo mật bằng ACL, hỗ trợ
**secure dynamic update**. → Bản ghi DNS là **object AD** có ACL → user thường
thường **tạo được bản ghi** (lạm dụng: ADIDNS).

---

## Dynamic Update & ADIDNS attack
**Định nghĩa:** client tự đăng ký bản ghi DNS của mình (A record). Với **secure
dynamic update**, user đã xác thực ghi được record.

**Chi tiết tấn công (ADIDNS):** domain user tạo/sửa record trỏ tên về IP attacker
→ phục vụ poisoning/relay (vd tạo record `wpad`, hoặc trỏ tên tới máy attacker để
ép xác thực).

*Ví dụ:*
```bash
# Liệt kê record (kể cả ẩn)
adidnsdump -u corp.local\\alice -p 'Password123!' 10.10.10.100
# Thêm record trỏ về attacker (phục vụ coerce/relay)
dnstool.py -u 'corp.local\alice' -p 'Password123!' -r attacker.corp.local -a add -d 10.10.14.37 10.10.10.100
```

*Tài liệu:* [ADIDNS (The Hacker Recipes)](https://www.thehacker.recipes/ad/movement/mitm-and-coerced-authentications/adidns-spoofing).

---

## Zone transfer (AXFR)
**Định nghĩa:** sao chép toàn bộ zone sang server khác. Nếu DNS cho phép AXFR với
bất kỳ ai → lộ toàn bộ host.

*Ví dụ:*
```bash
dig axfr corp.local @10.10.10.100
```

---

## Conditional Forwarder & Stub zone
- **Conditional forwarder:** chuyển truy vấn cho một domain cụ thể sang DNS khác
  (thường dùng với **trust** để phân giải tên domain đối tác).
- **Stub zone:** bản sao nhẹ chỉ giữ NS/SOA của zone khác.

Hiểu để biết vì sao đôi khi phải **thêm `/etc/hosts`** hoặc trỏ `-ns` tới đúng DC
khi tool không phân giải được tên domain con/đối tác.
