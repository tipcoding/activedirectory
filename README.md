# Active Directory — Tài liệu học & ôn thi OSCP

Repo tổng hợp tài liệu **Active Directory** cho học tập và kỳ thi OSCP: lý thuyết
khái niệm, các attack path theo mindmap Orange Cyberdefense, quy trình luyện thi,
và hướng dẫn công cụ BloodHound. Tất cả viết chi tiết bằng tiếng Việt, kèm lệnh
cụ thể (Kali + Windows), điều kiện chạy, kết quả mong đợi, lý do và bài lab.

> Chỉ dùng trong môi trường lab / kỳ thi / pentest có ủy quyền.

## Bốn bộ tài liệu

| Thư mục | Nội dung | Bắt đầu |
|---------|----------|---------|
| 📘 [`AD-concepts/`](AD-concepts/README.md) | **Lý thuyết** — giải thích mọi khái niệm AD, ví dụ, link tài liệu gốc | [README](AD-concepts/README.md) |
| 🗺️ [`mindmaps/AD-2025.03/`](mindmaps/AD-2025.03/README.md) | **Attack paths** — giải thích từng box/bảng của OCD AD Mindmap v2025.03 | [README](mindmaps/AD-2025.03/README.md) |
| 🎯 [`OSCP-AD/`](OSCP-AD/README.md) | **Quy trình luyện thi** — kỹ thuật theo trạng thái + lab + cheatsheet | [README](OSCP-AD/README.md) |
| 🩸 [`bloodhound/`](bloodhound/README.md) | **Công cụ** — BloodHound/SharpHound, phiên bản, collector, theo OS | [README](bloodhound/README.md) |

Gợi ý lộ trình: đọc **AD-concepts** để hiểu bản chất → **mindmaps/AD-2025.03** để
thấy đường tấn công → **OSCP-AD** để luyện quy trình & lab → **bloodhound** khi
cần dựng bản đồ tấn công.

---

## 📘 AD-concepts — Giải thích mọi khái niệm AD

Định nghĩa chi tiết từng khái niệm, ví dụ minh hoạ, link tài liệu gốc (Microsoft
Learn, RFC, sách). Có thư mục sách & tài liệu tham khảo trong [README](AD-concepts/README.md).

| # | File | Khái niệm chính |
|---|------|-----------------|
| 01 | [directory-va-ldap](AD-concepts/01-directory-va-ldap.md) | Directory service, X.500, LDAP, rootDSE, ADSI/ADWS, naming context |
| 02 | [cau-truc-logic](AD-concepts/02-cau-truc-logic.md) | Forest, Tree, Domain, OU, Object, naming (DN/RDN/UPN), GUID, SID/RID |
| 03 | [cau-truc-vat-ly](AD-concepts/03-cau-truc-vat-ly.md) | DC, Site/Subnet, Replication, Global Catalog, RODC, SYSVOL |
| 04 | [schema](AD-concepts/04-schema.md) | Schema, class, attribute, objectClass, userAccountControl flags |
| 05 | [objects-security-principals](AD-concepts/05-objects-security-principals.md) | User, Computer, MSA/gMSA, krbtgt, MachineAccountQuota |
| 06 | [groups](AD-concepts/06-groups.md) | Security/Distribution, scope, nesting, AGDLP, nhóm đặc quyền |
| 07 | [xac-thuc-kerberos-ntlm](AD-concepts/07-xac-thuc-kerberos-ntlm.md) | NTLM, Kerberos, TGT/TGS, KDC, PAC, SPN, delegation |
| 08 | [uy-quyen-security-descriptor](AD-concepts/08-uy-quyen-security-descriptor.md) | Access token, SID, Security Descriptor, ACL/ACE, privileges |
| 09 | [group-policy](AD-concepts/09-group-policy.md) | GPO, GPC/GPT, LSDOU, inheritance, GPP cpassword |
| 10 | [dns](AD-concepts/10-dns.md) | DNS trong AD, SRV records, AD-integrated zone, ADIDNS |
| 11 | [trusts](AD-concepts/11-trusts.md) | Trust: loại, hướng, transitivity, SID filtering, SID history |
| 12 | [replication-va-fsmo](AD-concepts/12-replication-va-fsmo.md) | Multi-master replication, USN, KCC, partitions, 5 FSMO roles |
| 13 | [adcs-pki](AD-concepts/13-adcs-pki.md) | AD CS, CA, certificate template, enrollment, PKINIT, EKU |
| 14 | [credentials-va-secrets](AD-concepts/14-credentials-va-secrets.md) | NT hash, SAM, LSASS, DPAPI, NTDS.dit, DCC2, LAPS, gMSA |
| 15 | [mo-hinh-bao-mat-tiering](AD-concepts/15-mo-hinh-bao-mat-tiering.md) | Tier model, Protected Users, AdminSDHolder/SDProp, PAW |
| 16 | [hybrid-entra-azuread](AD-concepts/16-hybrid-entra-azuread.md) | Entra ID, AD Connect, PHS/PTA/Federation, Golden SAML |
| 17 | [thuat-ngu-tra-cuu](AD-concepts/17-thuat-ngu-tra-cuu.md) | Bảng tra cứu thuật ngữ & viết tắt A→Z |
| 18 | [kerberos-attacks](AD-concepts/18-kerberos-attacks.md) | Kerberos Attacks deep-dive (AS-REP/Kerberoast, delegation, Golden/Silver, PtT) |

---

## 🗺️ mindmaps/AD-2025.03 — Giải thích OCD AD Mindmap v2025.03

Đọc kỹ từng box/bảng của mindmap (trích xuất từ file SVG gốc, có **backup SVG**
trong thư mục). Mỗi box: khi nào chạy được, lệnh cụ thể, kết quả, tại sao dùng.

| # | File | Nhánh mindmap |
|---|------|---------------|
| 00 | [ky-hieu-va-cach-doc](mindmaps/AD-2025.03/00-ky-hieu-va-cach-doc.md) | Ký hiệu, biến dùng chung, bảng hash + hashcat mode |
| 01 | [no-credentials](mindmaps/AD-2025.03/01-no-credentials.md) | Scan, null/guest, poisoning, relay, coerce, known-vulns, PXE |
| 02 | [valid-user-no-password](mindmaps/AD-2025.03/02-valid-user-no-password.md) | User enum, AS-REP, spray, timeroast |
| 03 | [valid-credentials-enum](mindmaps/AD-2025.03/03-valid-credentials-enum.md) | ldeep/BloodHound, shares, Kerberoast, GPP, DNS |
| 04 | [low-access-privesc](mindmaps/AD-2025.03/04-low-access-privesc.md) | AppLocker/UAC bypass, Potato, winPEAS, service CVEs |
| 05 | [kerberos-delegation](mindmaps/AD-2025.03/05-kerberos-delegation.md) | Unconstrained/constrained/RBCD, S4U, KrbRelayUp |
| 06 | [adcs](mindmaps/AD-2025.03/06-adcs.md) | ESC1–ESC15, Certifried, relay, shadow credentials |
| 07 | [credentials-harvesting](mindmaps/AD-2025.03/07-credentials-harvesting.md) | LSASS/SAM/LSA/DPAPI/NTDS/gMSA/LAPS/KeePass |
| 08 | [lateral-movement](mindmaps/AD-2025.03/08-lateral-movement.md) | PtH/PtT/OverPtH, psexec/wmiexec/winrm/rdp |
| 09 | [acl-ace-abuse](mindmaps/AD-2025.03/09-acl-ace-abuse.md) | GenericAll/Write, WriteDacl/Owner, GPO, DNSAdmins, OU |
| 10 | [sccm](mindmaps/AD-2025.03/10-sccm.md) | SCCM: recon/elevate/takeover/creds/exec |
| 11 | [mssql](mindmaps/AD-2025.03/11-mssql.md) | xp_cmdshell, impersonate, linked servers, coerce |
| 12 | [domain-admin-persistence](mindmaps/AD-2025.03/12-domain-admin-persistence.md) | DCSync, Golden/Silver/Diamond/Sapphire, Skeleton, DSRM |
| 13 | [trusts](mindmaps/AD-2025.03/13-trusts.md) | Child-parent SID history, trust ticket, forest |
| 14 | [ntlm-relay](mindmaps/AD-2025.03/14-ntlm-relay.md) | Relay LDAP/SMB/HTTP-ADCS/RPC/MSSQL/dcsync |

---

## 🎯 OSCP-AD — Quy trình luyện thi

Kỹ thuật sắp theo **trạng thái bạn đang có** (từ không credential tới Domain
Admin), kèm danh sách lab và cheatsheet.

| # | File | Chủ đề |
|---|------|--------|
| 00 | [chuan-bi-cong-cu](OSCP-AD/00-chuan-bi-cong-cu.md) | Chuẩn bị tool, /etc/hosts, krb5.conf, đồng bộ giờ |
| 01 | [khong-co-credential](OSCP-AD/01-khong-co-credential.md) | Không credential: enum, poisoning, relay, coerce |
| 02 | [co-username](OSCP-AD/02-co-username.md) | Có username: AS-REP roast, password spraying |
| 03 | [co-credential-enum](OSCP-AD/03-co-credential-enum.md) | Có credential: BloodHound, Kerberoast, share/GPP, MSSQL |
| 04 | [leo-thang-acl-delegation](OSCP-AD/04-leo-thang-acl-delegation.md) | ACL/ACE, nhóm đặc quyền, LAPS, gMSA, delegation, shadow creds |
| 05 | [adcs](OSCP-AD/05-adcs.md) | ADCS ESC1–ESC16 |
| 06 | [local-admin-dump-credential](OSCP-AD/06-local-admin-dump-credential.md) | Privesc local + dump credential |
| 07 | [lateral-movement-pivoting](OSCP-AD/07-lateral-movement-pivoting.md) | Lateral movement + pivoting (ligolo-ng/chisel) |
| 08 | [domain-admin-persistence](OSCP-AD/08-domain-admin-persistence.md) | DCSync, NTDS.dit, Golden/Silver ticket |
| 09 | [trust](OSCP-AD/09-trust.md) | Domain/forest trust |
| 10 | [labs](OSCP-AD/10-labs.md) | Danh sách lab theo kỹ thuật (HTB/PG/THM/PEN-200/GOAD/Vulnlab) |
| 11 | [quy-trinh-thi-oscp](OSCP-AD/11-quy-trinh-thi-oscp.md) | Quy trình thi + quản lý thời gian |
| 12 | [cheatsheet](OSCP-AD/12-cheatsheet.md) | Cheatsheet 1 trang |

---

## 🩸 bloodhound — BloodHound & SharpHound

Kiến trúc, phiên bản (Legacy vs CE), các collector/biến thể, chạy trên từng hệ
điều hành, import & truy vấn, khắc phục sự cố.

| # | File | Nội dung |
|---|------|----------|
| 01 | [kien-truc-va-phien-ban](bloodhound/01-kien-truc-va-phien-ban.md) | Legacy 4.x vs CE, SharpHound v1 vs v2, bảng tương thích |
| 02 | [cai-dat](bloodhound/02-cai-dat.md) | Cài theo OS: Kali/Linux, Windows, macOS, Docker |
| 03 | [sharphound](bloodhound/03-sharphound.md) | SharpHound (.exe/.ps1), CollectionMethods, OPSEC/loop |
| 04 | [collectors-da-nen-tang](bloodhound/04-collectors-da-nen-tang.md) | bloodhound-python, ce-python, rusthound, nxc, SOAPHound |
| 05 | [azurehound](bloodhound/05-azurehound.md) | AzureHound cho Entra ID / Azure |
| 06 | [import-va-truy-van](bloodhound/06-import-va-truy-van.md) | Import, Mark Owned, Cypher, pathfinding |
| 07 | [chon-collector-theo-tinh-huong](bloodhound/07-chon-collector-theo-tinh-huong.md) | Ma trận chọn collector theo OS/tình huống/phiên bản |
| 08 | [khac-phuc-su-co-va-opsec](bloodhound/08-khac-phuc-su-co-va-opsec.md) | Version mismatch, DNS, clock skew, OPSEC/detection |

---

## Nguồn tham khảo chính
- OCD mindmaps — https://orange-cyberdefense.github.io/ocd-mindmaps/
- The Hacker Recipes — https://www.thehacker.recipes/
- HackTricks (AD) — https://book.hacktricks.xyz/windows-hardening/active-directory-methodology
- BloodHound docs — https://bloodhound.specterops.io/
- adsecurity.org — https://adsecurity.org/
- Microsoft Learn (AD DS) — https://learn.microsoft.com/windows-server/identity/ad-ds/

(Chi tiết sách/RFC/tài liệu gốc xem [AD-concepts/README.md](AD-concepts/README.md).)

---

CDCyber Academy
