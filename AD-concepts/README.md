# AD-concepts — Giải thích chi tiết mọi khái niệm Active Directory

Thư mục này giải thích **từng khái niệm** trong môi trường Active Directory: định
nghĩa, chi tiết cách hoạt động, **ví dụ minh hoạ cụ thể**, và **link tới tài liệu
gốc** (Microsoft Learn, RFC, sách, tài liệu bảo mật). Mục tiêu: hiểu *bản chất*
để vừa quản trị vừa pentest AD.

> Dùng cho học tập / lab / pentest có ủy quyền.

## Cách dùng

Mỗi file là một nhóm khái niệm. Trong file, mỗi khái niệm theo cấu trúc:

> **Khái niệm** — định nghĩa ngắn → giải thích chi tiết → *Ví dụ* → *Tài liệu gốc*.

## Mục lục khái niệm

| # | File | Khái niệm chính |
|---|------|-----------------|
| 01 | [01-directory-va-ldap.md](01-directory-va-ldap.md) | Directory service, X.500, LDAP, DIT, bind, schema-overview, ADSI, ADWS |
| 02 | [02-cau-truc-logic.md](02-cau-truc-logic.md) | Forest, Tree, Domain, OU, Object, Container, naming (DN/RDN/CN/DC/UPN/sAMAccountName), GUID, SID, namespace |
| 03 | [03-cau-truc-vat-ly.md](03-cau-truc-vat-ly.md) | Domain Controller, Site, Subnet, Replication, Global Catalog, RODC, SYSVOL/NETLOGON |
| 04 | [04-schema.md](04-schema.md) | Schema, class, attribute, objectClass, syntax, LDAP display name, schema master |
| 05 | [05-objects-security-principals.md](05-objects-security-principals.md) | User, Computer, Contact, MSA/gMSA, InetOrgPerson, foreignSecurityPrincipal, UAC flags |
| 06 | [06-groups.md](06-groups.md) | Security vs Distribution, scope (Domain Local/Global/Universal), nesting, AGDLP, built-in & well-known groups |
| 07 | [07-xac-thuc-kerberos-ntlm.md](07-xac-thuc-kerberos-ntlm.md) | NTLM, Kerberos, TGT/TGS, KDC, AS/TGS-REQ, PAC, SPN, pre-auth, salt, etypes, delegation |
| 08 | [08-uy-quyen-security-descriptor.md](08-uy-quyen-security-descriptor.md) | Access token, SID/RID, well-known SID, Security Descriptor, DACL/SACL, ACE, quyền (privileges), rights vs permissions |
| 09 | [09-group-policy.md](09-group-policy.md) | GPO, GPC/GPT, SYSVOL, link/scope/precedence (LSDOU), inheritance, loopback, security filtering, GPP |
| 10 | [10-dns.md](10-dns.md) | DNS trong AD, SRV records, AD-integrated zone, dynamic update, ADIDNS, `_msdcs` |
| 11 | [11-trusts.md](11-trusts.md) | Trust, direction, transitivity, loại (parent-child/tree-root/external/forest/realm/shortcut), SID filtering, SID history |
| 12 | [12-replication-va-fsmo.md](12-replication-va-fsmo.md) | Multi-master replication, USN, high-watermark, KCC, partitions (NC), 5 FSMO roles |
| 13 | [13-adcs-pki.md](13-adcs-pki.md) | AD CS, CA (enterprise/standalone), certificate template, enrollment, PKINIT, EKU, CRL |
| 14 | [14-credentials-va-secrets.md](14-credentials-va-secrets.md) | NTDS.dit, SAM, LSASS, LSA secrets, DPAPI, krbtgt, cached creds (DCC2), tokens, LAPS, gMSA password |
| 15 | [15-mo-hinh-bao-mat-tiering.md](15-mo-hinh-bao-mat-tiering.md) | Tier model, Protected Users, AdminSDHolder/SDProp, adminCount, PAW, LAPS, RBAC, least privilege |
| 16 | [16-hybrid-entra-azuread.md](16-hybrid-entra-azuread.md) | Entra ID (Azure AD), AD Connect, PHS/PTA/Federation, seamless SSO, hybrid join |
| 17 | [17-thuat-ngu-tra-cuu.md](17-thuat-ngu-tra-cuu.md) | Bảng tra cứu nhanh thuật ngữ & viết tắt (A→Z) |

## 📚 Sách & tài liệu gốc (bibliography)

### Sách
- **"Active Directory, 5th Edition"** — Brian Desmond, Joe Richards, Robbie Allen,
  Alistair Lowe-Norris (O'Reilly, 2013). ISBN 978-1449320027. *Kinh điển về quản trị AD.*
- **"Windows Server 2019 Inside Out"** — Orin Thomas (Microsoft Press).
- **"Active Directory Administration Cookbook"** — Sander Berkouwer (Packt).
- **"The Art of Network Penetration Testing"** / **"Pentesting Active Directory"** tài liệu cộng đồng.
- **"Windows Internals, 7th Ed"** — Russinovich, Solomon, Ionescu (Microsoft Press)
  — phần LSASS, token, SID, DPAPI.

### Tài liệu chính thức Microsoft
- Active Directory Domain Services overview — https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview
- AD DS các khái niệm — https://learn.microsoft.com/windows-server/identity/ad-ds/ad-ds-getting-started
- **[MS-ADTS]** Active Directory Technical Specification — https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/
- **[MS-KILE]** Kerberos Protocol Extensions — https://learn.microsoft.com/openspecs/windows_protocols/ms-kile/
- **[MS-PAC]** Privilege Attribute Certificate — https://learn.microsoft.com/openspecs/windows_protocols/ms-pac/
- **[MS-NLMP]** NTLM — https://learn.microsoft.com/openspecs/windows_protocols/ms-nlmp/
- **[MS-GPOL]** Group Policy — https://learn.microsoft.com/openspecs/windows_protocols/ms-gpol/
- Security identifiers (well-known SIDs) — https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers
- AD CS — https://learn.microsoft.com/windows-server/identity/ad-cs/

### RFC (chuẩn gốc)
- **RFC 4120** — The Kerberos Network Authentication Service (V5) — https://www.rfc-editor.org/rfc/rfc4120
- **RFC 4511** — LDAP: The Protocol — https://www.rfc-editor.org/rfc/rfc4511
- **RFC 4514** — LDAP: String Representation of Distinguished Names — https://www.rfc-editor.org/rfc/rfc4514
- **RFC 2782** — DNS SRV records — https://www.rfc-editor.org/rfc/rfc2782
- **RFC 3244** — Kerberos Set/Change Password — https://www.rfc-editor.org/rfc/rfc3244

### Tài liệu bảo mật (tấn công/phòng thủ)
- **The Hacker Recipes** — https://www.thehacker.recipes/ (giải thích + lệnh từng kỹ thuật AD)
- **ired.team** — https://www.ired.team/ (offensive AD notes)
- **HackTricks — AD** — https://book.hacktricks.xyz/windows-hardening/active-directory-methodology
- **SpecterOps blog / BloodHound docs** — https://bloodhound.specterops.io/
- **adsecurity.org** (Sean Metcalf) — https://adsecurity.org/ (Kerberos, krbtgt, delegation)
- **Orange Cyberdefense mindmaps** — https://orange-cyberdefense.github.io/ocd-mindmaps/
- **Microsoft "Securing Privileged Access" / Tier model** — https://learn.microsoft.com/security/privileged-access-workstations/

> Các liên kết là tài liệu gốc tại thời điểm viết; nếu Microsoft đổi URL, tìm
> theo tên `[MS-ADTS]`, `[MS-KILE]`… trên learn.microsoft.com.

## Liên quan trong repo
- Khai thác từng kỹ thuật: [`../mindmaps/AD-2025.03/`](../mindmaps/AD-2025.03/README.md)
- Quy trình luyện thi OSCP: [`../OSCP-AD/`](../OSCP-AD/README.md)
- Công cụ BloodHound: [`../bloodhound/`](../bloodhound/README.md)
