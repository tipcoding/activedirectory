# 16 — Hybrid: Entra ID (Azure AD) & AD Connect

Môi trường hiện đại thường **lai (hybrid)**: AD on-prem + **Entra ID** (tên mới
của Azure AD) trên cloud. Hiểu khái niệm để nối chặng on-prem ↔ cloud.

---

## Entra ID (Azure AD)
**Định nghĩa:** dịch vụ danh tính đám mây của Microsoft (Microsoft 365, Azure).
**Không phải** AD DS — không có OU/GPO/Kerberos/LDAP theo kiểu on-prem; dùng
**OAuth2/OIDC/SAML**, Microsoft Graph API.

**Chi tiết khác biệt chính:**
| | AD DS (on-prem) | Entra ID (cloud) |
|---|-----------------|------------------|
| Giao thức | Kerberos/NTLM/LDAP | OAuth2/OIDC/SAML/Graph |
| Cấu trúc | forest/domain/OU | tenant/phẳng |
| Chính sách | GPO | Conditional Access, Intune |
| Quản trị | Domain/Enterprise Admins | Global Admin, roles |

*Tài liệu:* [What is Entra ID](https://learn.microsoft.com/entra/fundamentals/whatis).

---

## Azure AD Connect (Entra Connect)
**Định nghĩa:** công cụ **đồng bộ** danh tính on-prem lên Entra ID → user dùng
cùng tài khoản cho cả hai.

**Chi tiết an ninh:** server chạy AD Connect là **mục tiêu giá trị cao**:
- Chứa tài khoản **MSOL_** (connector account) thường có **quyền DCSync** on-prem.
- Lưu bí mật để đồng bộ → giải mã được (xem
  [mindmaps/12 §Hybrid](../mindmaps/AD-2025.03/12-domain-admin-persistence.md)).

*Ví dụ:*
```bash
nxc ldap <dc> -u alice -p 'pass' -M get-desc-users | grep -i MSOL   # tìm tài khoản MSOL
nxc smb <adconnect> -u alice -p 'pass' -M msol                      # dump creds MSOL
```

---

## Phương thức đồng bộ xác thực
| Phương thức | Mô tả | Rủi ro |
|-------------|-------|--------|
| **PHS (Password Hash Sync)** | đồng bộ **hash của hash** NT lên cloud | lấy được → đăng nhập cloud; MSOL có DCSync |
| **PTA (Pass-Through Authentication)** | cloud chuyển xác thực về agent on-prem | agent PTA bị chiếm → bắt mật khẩu plaintext |
| **Federation (ADFS)** | ADFS on-prem phát hành token SAML | lấy **token-signing key** → **Golden SAML** (giả bất kỳ user cloud) |

*Tài liệu:* [Choose auth method](https://learn.microsoft.com/entra/identity/hybrid/connect/choose-ad-authn).

---

## Seamless SSO & Hybrid Join
- **Seamless SSO:** tự đăng nhập cloud khi đang trong domain on-prem; dùng tài
  khoản máy **`AZUREADSSOACC$`** (hash của nó → forge Kerberos tới cloud =
  "Silver ticket" cho SSO).
- **Hybrid Azure AD Join:** máy vừa join AD on-prem vừa đăng ký Entra ID.

---

## Golden SAML (khái niệm)
**Định nghĩa:** nếu có **private key ký token** của ADFS, forge token SAML cho
**bất kỳ** user cloud, bỏ qua mật khẩu & MFA → persistence cloud rất mạnh.

*Tài liệu:* [Golden SAML (CyberArk)](https://www.cyberark.com/resources/threat-research-blog/golden-saml-newly-discovered-attack-technique-forges-authentication-to-cloud-apps).

---

## AzureHound (phân tích đồ thị cloud)
Thu dữ liệu Entra/Azure cho BloodHound — xem
[`../bloodhound/05-azurehound.md`](../bloodhound/05-azurehound.md).

---

## Khi nào quan tâm phần này
- OSCP truyền thống: **hiếm**.
- Red team / pentest hiện đại: **thường** — chặng "on-prem → cloud" qua AD Connect
  (MSOL DCSync), hoặc "cloud → on-prem" qua Intune/Hybrid.

*Tài liệu bổ sung:* [Entra security](https://learn.microsoft.com/entra/identity/),
[The Hacker Recipes — Azure](https://www.thehacker.recipes/).
