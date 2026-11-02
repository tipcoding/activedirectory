# 07 — Xác thực: NTLM & Kerberos

Hai giao thức xác thực chính trong AD. Hiểu kỹ phần này là nền cho gần như mọi
tấn công AD.

---

## NTLM (NT LAN Manager)
**Định nghĩa:** giao thức xác thực **challenge-response** cũ của Windows, dùng
khi không thể dùng Kerberos (truy cập bằng IP, workgroup, legacy).

**Chi tiết — luồng NTLMv2:**
1. Client gửi **NEGOTIATE**.
2. Server gửi **CHALLENGE** (một nonce ngẫu nhiên).
3. Client trả **AUTHENTICATE** = HMAC của challenge với **NT hash** của user.
4. Server (hoặc DC qua Netlogon) xác minh.

- **NT hash** = `MD4(UTF16-LE(password))` — *không salt* → **Pass-the-Hash** được
  (dùng chính NT hash để tính response, không cần plaintext).
- **NetNTLMv2** (response bắt được qua Responder) **có** challenge → **không**
  PtH, chỉ **crack offline** (`hashcat -m 5600`).

*Ví dụ NT hash:* `Administrator:500:aad3b435...:2b576acbe6bcfda7294d6bd18041b8fe:::`
(phần sau dấu `:` thứ 3 là NT hash).

*Tài liệu gốc:* [[MS-NLMP] NTLM](https://learn.microsoft.com/openspecs/windows_protocols/ms-nlmp/).

### Vì sao NTLM nguy hiểm
- **Pass-the-Hash**: NT hash = "mật khẩu" cho NTLM.
- **NTLM relay**: không ký → relay sang dịch vụ khác (xem [file 11 §relay] và
  [mindmaps/14](../mindmaps/AD-2025.03/14-ntlm-relay.md)).

---

## Kerberos — tổng quan
**Định nghĩa:** giao thức xác thực mặc định của AD (RFC 4120), dựa trên **vé
(ticket)** và **bên thứ ba tin cậy** là **KDC** (chạy trên DC).

**Thành phần:**
- **KDC (Key Distribution Center):** gồm **AS (Authentication Service)** và
  **TGS (Ticket Granting Service)**; chạy trên mọi DC.
- **Principal:** user/service, định danh bằng tên + realm (`alice@CORP.LOCAL`).
- **Realm:** = domain, **viết HOA** theo quy ước (`CORP.LOCAL`).
- **Long-term key:** khóa dẫn xuất từ mật khẩu (RC4 = NT hash; AES = PBKDF2 có salt).

*Tài liệu gốc:* [RFC 4120](https://www.rfc-editor.org/rfc/rfc4120),
[[MS-KILE]](https://learn.microsoft.com/openspecs/windows_protocols/ms-kile/).

---

## Luồng Kerberos (chi tiết từng bước)
```
         ┌── 1. AS-REQ (timestamp mã hoá bằng khóa user = pre-auth) ──►
 Client  │                                                            KDC/AS
         ◄── 2. AS-REP (TGT + session key, mã hoá bằng khóa krbtgt) ──┘

         ┌── 3. TGS-REQ (xuất trình TGT + xin dịch vụ SPN) ──────────►
 Client  │                                                            KDC/TGS
         ◄── 4. TGS-REP (service ticket/TGS mã hoá bằng khóa service)┘

         ┌── 5. AP-REQ (xuất trình TGS tới service) ──────────────────►
 Client  │                                                            Service
         ◄── 6. AP-REP (tuỳ chọn, xác thực lẫn nhau) ─────────────────┘
```

1. **AS-REQ / Pre-authentication:** client mã hoá timestamp bằng khóa của mình
   để chứng minh biết mật khẩu. *Nếu tắt pre-auth* → **AS-REP Roasting** (xin
   AS-REP không cần mật khẩu, crack phần mã hoá bằng khóa user — `-m 18200`).
2. **AS-REP:** chứa **TGT** (mã hoá bằng khóa `krbtgt` → chỉ KDC đọc được) và
   **session key**.
3. **TGS-REQ:** client gửi TGT + yêu cầu vé cho một **SPN** cụ thể.
4. **TGS-REP:** chứa **service ticket (TGS)** mã hoá bằng **khóa của tài khoản
   dịch vụ** → **Kerberoasting** (bất kỳ user xin được TGS, crack phần này để lấy
   mật khẩu service — `-m 13100`).
5. **AP-REQ:** client xuất trình TGS tới service; service giải bằng khóa của mình.

---

## TGT vs TGS (Service Ticket)
| | **TGT** | **TGS / Service Ticket** |
|---|---------|--------------------------|
| Cấp bởi | AS | TGS |
| Mã hoá bằng | khóa **krbtgt** | khóa **tài khoản service** |
| Dùng để | xin các TGS | truy cập **1 service** |
| Lạm dụng | **Golden Ticket** (có krbtgt hash) | **Silver Ticket** (có service hash) |

*Ví dụ:* `.ccache`/`.kirbi` chứa ticket; dùng Pass-the-Ticket (`-k -no-pass`).

---

## PAC (Privilege Attribute Certificate)
**Định nghĩa:** phần đính trong ticket chứa **SID user + các nhóm** → service
biết user thuộc nhóm nào mà không query lại.

**Chi tiết:** PAC được ký bằng khóa krbtgt + khóa service. Lỗ hổng **MS14-068**
cho phép forge PAC (thêm mình vào Domain Admins). **PAC validation** và các bản
vá (CVE-2021-42287/noPac, CVE-2022-37967) quanh PAC rất quan trọng.

*Tài liệu gốc:* [[MS-PAC]](https://learn.microsoft.com/openspecs/windows_protocols/ms-pac/).

---

## SPN (Service Principal Name)
**Định nghĩa:** tên định danh một **instance dịch vụ** để Kerberos cấp vé, dạng
`<class>/<host>[:port][/service]`.

*Ví dụ:* `MSSQLSvc/sql01.corp.local:1433`, `HTTP/web01.corp.local`,
`CIFS/fileserver.corp.local`, `HOST/dc01` (bao nhiều service).

**Chi tiết:** SPN gắn vào tài khoản (user hoặc máy) chạy dịch vụ. **User có SPN**
= kerberoastable. Trùng SPN gây lỗi đăng nhập.

*Ví dụ liệt kê:*
```bash
setspn -T corp.local -Q */*
GetUserSPNs.py corp.local/alice:'Password123!' -dc-ip 10.10.10.100
```

---

## Salt & Encryption types (etypes)
**Định nghĩa:** Kerberos hỗ trợ nhiều thuật toán: **RC4-HMAC** (23, = NT hash,
*không salt*), **AES128** (17), **AES256** (18, có salt = realm+username).

**Chi tiết:** RC4 dễ crack hơn → kỹ thuật "**tgtdeleg**"/`/tgtdeleg` ép RC4 khi
kerberoast. Salt AES = `CORP.LOCALalice` (realm HOA + username).

---

## Delegation (khái niệm)
Cho phép một service **mạo danh user** tới service khác. Ba loại:
- **Unconstrained** — service lưu TGT của user → mạo danh ở mọi nơi (nguy hiểm nhất).
- **Constrained** — chỉ tới các SPN được liệt kê (`msDS-AllowedToDelegateTo`); dùng S4U2Self/S4U2Proxy.
- **Resource-Based (RBCD)** — máy đích quyết định ai được mạo danh tới nó
  (`msDS-AllowedToActOnBehalfOfOtherIdentity`).

Khai thác chi tiết: [mindmaps/05](../mindmaps/AD-2025.03/05-kerberos-delegation.md).
*Tài liệu:* [Kerberos delegation](https://learn.microsoft.com/windows-server/security/kerberos/kerberos-constrained-delegation-overview),
[adsecurity.org Kerberos](https://adsecurity.org/?page_id=1821).

---

## Các lỗi Kerberos hay gặp (và nghĩa)
| Lỗi | Nghĩa |
|-----|-------|
| `KRB_AP_ERR_SKEW` | lệch giờ > 5 phút → đồng bộ NTP |
| `KDC_ERR_PREAUTH_REQUIRED` | user tồn tại, cần pre-auth (dùng trong user enum) |
| `KDC_ERR_C_PRINCIPAL_UNKNOWN` | user không tồn tại / sai realm |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN` | SPN không tồn tại |
| `KRB_AP_ERR_MODIFIED` | sai khóa service (silver ticket sai hash) |

> Kerberos **bắt buộc FQDN + đồng bộ giờ + realm HOA** — xem thiết lập ở
> [OSCP-AD/00](../OSCP-AD/00-chuan-bi-cong-cu.md).
