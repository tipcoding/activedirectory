# 13 — AD Certificate Services (AD CS / PKI)

## PKI & AD CS
**Định nghĩa:** **PKI** (Public Key Infrastructure) quản lý **chứng chỉ số**.
**AD CS** là triển khai PKI của Microsoft, tích hợp AD — cấp chứng chỉ cho user,
máy, dịch vụ (smartcard logon, VPN, HTTPS nội bộ, mã hoá…).

**Chi tiết:** cấu hình sai trong AD CS là đường leo thang rất mạnh (ESC1–ESC16).
Hiểu khái niệm trước khi khai thác ([mindmaps/06](../mindmaps/AD-2025.03/06-adcs.md)).

*Tài liệu gốc:* [AD CS](https://learn.microsoft.com/windows-server/identity/ad-cs/),
[SpecterOps "Certified Pre-Owned"](https://posts.specterops.io/certified-pre-owned-d95910965cd2).

---

## Certification Authority (CA)
**Định nghĩa:** thực thể cấp và ký chứng chỉ.
- **Enterprise CA:** tích hợp AD (object trong `CN=Configuration`), phát hành
  theo **template**, tự động tin cậy trong forest (NTAuth store).
- **Standalone CA:** không tích hợp AD.

**Chi tiết:** **Root CA** tự ký (gốc tin cậy); **Subordinate/Issuing CA** do root
ký, trực tiếp cấp cho end-entity. Khóa riêng của CA = "chìa khóa vương quốc" →
lấy được → **Golden Certificate** (forge chứng chỉ bất kỳ).

*Ví dụ liệt kê CA:*
```bash
certipy find -u alice@corp.local -p 'Password123!' -dc-ip 10.10.10.100 -stdout
certutil -TCAInfo
```

---

## Certificate Template
**Định nghĩa:** "khuôn" quy định chứng chỉ cấp ra: ai được enroll, EKU (mục đích),
có cho đặt SAN không, có cần phê duyệt không…

**Chi tiết thuộc tính quan trọng (quyết định ESCx):**
| Thuộc tính template | Ý nghĩa |
|---------------------|---------|
| **Enrollment Rights** | ai được xin chứng chỉ |
| **Enrollee Supplies Subject** | client tự đặt **SAN** → mạo danh (ESC1) |
| **EKU / Application Policies** | mục đích: Client Authentication / Any Purpose / Enrollment Agent |
| **Manager Approval** | cần duyệt tay hay không |
| **Schema version (V1/V2…)** | liên quan ESC15 (EKUwu) |

*Ví dụ:* template cho **Client Authentication** + **Enrollee Supplies Subject** +
cho user thường enroll = **ESC1** → xin chứng chỉ với SAN `administrator`.

---

## Enrollment (đăng ký chứng chỉ)
**Định nghĩa:** quá trình xin & nhận chứng chỉ. Kênh: **RPC (MS-ICPR)**,
**Web Enrollment** (`/certsrv`, HTTP — ESC8), **CES/CEP**, auto-enrollment.

*Ví dụ:*
```bash
certipy req -u alice@corp.local -p 'pass' -target CA01 -ca 'CORP-CA' -template 'VulnTemplate' -upn administrator@corp.local
```

---

## EKU (Extended Key Usage)
**Định nghĩa:** OID xác định **mục đích** của chứng chỉ.
- **Client Authentication** (`1.3.6.1.5.5.7.3.2`) → dùng xác thực (PKINIT) → nguy hiểm.
- **Smart Card Logon** (`1.3.6.1.4.1.311.20.2.2`).
- **Any Purpose** / **không EKU** → dùng mọi mục đích (ESC2).
- **Certificate Request Agent** (`1.3.6.1.4.1.311.20.2.1`) → enroll thay người khác (ESC3).

---

## PKINIT (Public Key Cryptography for Initial Authentication)
**Định nghĩa:** phần mở rộng Kerberos cho phép **dùng chứng chỉ thay mật khẩu** ở
bước AS-REQ để lấy TGT.

**Chi tiết:** có chứng chỉ client-auth của một user → PKINIT lấy **TGT** của user
đó, và qua **UnPAC-the-hash** lấy luôn **NT hash**. Đây là "Pass the Certificate".

*Ví dụ:*
```bash
certipy auth -pfx administrator.pfx -dc-ip 10.10.10.100   # → TGT + NT hash
```

*Tài liệu:* [RFC 4556 — PKINIT](https://www.rfc-editor.org/rfc/rfc4556).

---

## CRL, NTAuth, CA certificates store
- **CRL (Certificate Revocation List):** danh sách chứng chỉ bị thu hồi.
- **NTAuth store:** nơi liệt kê CA được phép **cấp chứng chỉ dùng cho xác thực
  domain** — CA phải nằm trong đây thì chứng chỉ mới logon được.
- **Root/Intermediate CA store:** chuỗi tin cậy.

---

## Các khái niệm ESC (tóm tắt — chi tiết ở mindmaps/06)
| ESC | Khái niệm sai lệch |
|-----|--------------------|
| ESC1 | template cho đặt SAN tùy ý |
| ESC2/3 | Any Purpose / Enrollment Agent |
| ESC4 | ghi được template |
| ESC6 | CA bật EDITF_ATTRIBUTESUBJECTALTNAME2 |
| ESC7 | quyền ManageCA/ManageCertificates |
| ESC8 | relay NTLM tới Web Enrollment |
| ESC9/10 | cert mapping yếu |
| ESC11 | relay tới RPC (ICPR) |
| ESC13/15 | issuance policy / EKUwu |

*Tài liệu gốc chuyên sâu:* [Certipy wiki](https://github.com/ly4k/Certipy),
["Certified Pre-Owned" whitepaper](https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf).
