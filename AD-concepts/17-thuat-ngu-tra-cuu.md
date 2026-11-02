# 17 — Bảng tra cứu thuật ngữ & viết tắt (A → Z)

| Thuật ngữ | Giải thích ngắn | Xem thêm |
|-----------|-----------------|----------|
| **ACE** | Access Control Entry — 1 mục trong DACL | [08](08-uy-quyen-security-descriptor.md) |
| **ACL (DACL/SACL)** | danh sách quyền trên object | [08](08-uy-quyen-security-descriptor.md) |
| **AD CS** | AD Certificate Services (PKI) | [13](13-adcs-pki.md) |
| **AD Connect** | đồng bộ on-prem ↔ Entra ID | [16](16-hybrid-entra-azuread.md) |
| **ADIDNS** | AD-Integrated DNS (lạm dụng dynamic update) | [10](10-dns.md) |
| **ADWS** | AD Web Services (9389), dùng bởi module AD/SOAPHound | [01](01-directory-va-ldap.md) |
| **AGDLP** | Account→Global→DomainLocal→Permission | [06](06-groups.md) |
| **AS / TGS** | Authentication / Ticket Granting Service (KDC) | [07](07-xac-thuc-kerberos-ntlm.md) |
| **AS-REP Roasting** | roast user tắt pre-auth | [07](07-xac-thuc-kerberos-ntlm.md) |
| **adminCount / SDProp** | cờ & tiến trình bảo vệ nhóm admin | [15](15-mo-hinh-bao-mat-tiering.md) |
| **CN / DN / RDN** | thành phần tên object | [02](02-cau-truc-logic.md) |
| **DACL** | Discretionary ACL | [08](08-uy-quyen-security-descriptor.md) |
| **DC** | Domain Controller | [03](03-cau-truc-vat-ly.md) |
| **DCSync** | giả DC xin hash qua replication | [12](12-replication-va-fsmo.md) |
| **DCShadow** | đăng ký DC giả đẩy thay đổi | [12](12-replication-va-fsmo.md) |
| **DCC2 / MSCache2** | cached domain creds (crack offline) | [14](14-credentials-va-secrets.md) |
| **Delegation** | unconstrained/constrained/RBCD | [07](07-xac-thuc-kerberos-ntlm.md) |
| **DIT** | Directory Information Tree | [01](01-directory-va-ldap.md) |
| **DPAPI** | API mã hoá bí mật người dùng | [14](14-credentials-va-secrets.md) |
| **EKU** | Extended Key Usage (mục đích chứng chỉ) | [13](13-adcs-pki.md) |
| **Entra ID** | Azure AD (danh tính cloud) | [16](16-hybrid-entra-azuread.md) |
| **ESC1-16** | cấu hình sai AD CS | [13](13-adcs-pki.md), [mindmaps/06](../mindmaps/AD-2025.03/06-adcs.md) |
| **FSMO** | 5 vai trò single-master | [12](12-replication-va-fsmo.md) |
| **FSP** | foreignSecurityPrincipal | [05](05-objects-security-principals.md) |
| **Forest** | ranh giới bảo mật cao nhất | [02](02-cau-truc-logic.md) |
| **GC** | Global Catalog (3268/3269) | [03](03-cau-truc-vat-ly.md) |
| **gMSA** | Group Managed Service Account | [05](05-objects-security-principals.md), [14](14-credentials-va-secrets.md) |
| **GPO / GPC / GPT** | Group Policy + 2 phần lưu trữ | [09](09-group-policy.md) |
| **GPP cpassword** | mật khẩu GPP mã hoá yếu (MS14-025) | [09](09-group-policy.md) |
| **GUID (objectGUID)** | định danh bất biến | [02](02-cau-truc-logic.md) |
| **KCC** | Knowledge Consistency Checker (topology replication) | [12](12-replication-va-fsmo.md) |
| **KDC** | Key Distribution Center (AS+TGS) | [07](07-xac-thuc-kerberos-ntlm.md) |
| **Kerberoasting** | crack TGS của user có SPN | [07](07-xac-thuc-kerberos-ntlm.md) |
| **krbtgt** | khóa ký TGT → Golden Ticket | [05](05-objects-security-principals.md), [14](14-credentials-va-secrets.md) |
| **LAPS** | mật khẩu admin local ngẫu nhiên theo máy | [14](14-credentials-va-secrets.md), [15](15-mo-hinh-bao-mat-tiering.md) |
| **LDAP / LDAPS** | giao thức truy vấn directory (389/636) | [01](01-directory-va-ldap.md) |
| **LM / NT hash** | hash mật khẩu Windows | [14](14-credentials-va-secrets.md) |
| **LSASS / LSA Secrets** | nơi giữ creds runtime / registry | [14](14-credentials-va-secrets.md) |
| **MAQ** | MachineAccountQuota (mặc định 10) | [05](05-objects-security-principals.md) |
| **MSA / MSOL** | Managed Service Account / tài khoản AD Connect | [05](05-objects-security-principals.md), [16](16-hybrid-entra-azuread.md) |
| **Naming Context / Partition** | phần DIT replicate độc lập | [01](01-directory-va-ldap.md), [12](12-replication-va-fsmo.md) |
| **NTDS.dit** | database AD trên DC | [03](03-cau-truc-vat-ly.md), [14](14-credentials-va-secrets.md) |
| **NTLM / NetNTLMv2** | xác thực challenge-response | [07](07-xac-thuc-kerberos-ntlm.md) |
| **OU** | Organizational Unit | [02](02-cau-truc-logic.md) |
| **PAC** | Privilege Attribute Certificate (trong ticket) | [07](07-xac-thuc-kerberos-ntlm.md) |
| **PAW** | Privileged Access Workstation | [15](15-mo-hinh-bao-mat-tiering.md) |
| **PKINIT** | Kerberos xác thực bằng chứng chỉ | [13](13-adcs-pki.md) |
| **Protected Users** | nhóm bảo vệ (cấm NTLM/delegation) | [15](15-mo-hinh-bao-mat-tiering.md) |
| **RBCD** | Resource-Based Constrained Delegation | [07](07-xac-thuc-kerberos-ntlm.md), [mindmaps/05](../mindmaps/AD-2025.03/05-kerberos-delegation.md) |
| **RID** | Relative ID (phần cuối SID) | [02](02-cau-truc-logic.md) |
| **RODC** | Read-Only Domain Controller | [03](03-cau-truc-vat-ly.md) |
| **SAM** | kho hash tài khoản local | [14](14-credentials-va-secrets.md) |
| **Schema** | định nghĩa class/attribute | [04](04-schema.md) |
| **SD / SDDL** | Security Descriptor & biểu diễn chuỗi | [08](08-uy-quyen-security-descriptor.md) |
| **Shadow Credentials** | ghi msDS-KeyCredentialLink → PKINIT | [13](13-adcs-pki.md), [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md) |
| **SID / SID History** | định danh bảo mật / lịch sử SID | [02](02-cau-truc-logic.md), [11](11-trusts.md) |
| **Site / Subnet** | cấu trúc vật lý mạng | [03](03-cau-truc-vat-ly.md) |
| **SPN** | Service Principal Name | [07](07-xac-thuc-kerberos-ntlm.md) |
| **SYSVOL / NETLOGON** | share chứa GPO/script | [03](03-cau-truc-vat-ly.md) |
| **TGT / TGS** | Ticket Granting Ticket / Service | [07](07-xac-thuc-kerberos-ntlm.md) |
| **Tier model** | phân tầng đặc quyền (Tier 0/1/2) | [15](15-mo-hinh-bao-mat-tiering.md) |
| **Trust** | quan hệ tin cậy domain/forest | [11](11-trusts.md) |
| **UAC flags** | userAccountControl bitmask | [04](04-schema.md) |
| **UPN** | userPrincipalName (user@domain) | [02](02-cau-truc-logic.md) |
| **USN** | Update Sequence Number (replication) | [12](12-replication-va-fsmo.md) |
| **Well-known SID** | SID cố định (SYSTEM, Everyone…) | [08](08-uy-quyen-security-descriptor.md) |

> Mỗi thuật ngữ trỏ tới file giải thích chi tiết trong `AD-concepts/`, và tới
> cách khai thác tương ứng trong `../mindmaps/AD-2025.03/` khi có.
