# Giải thích chi tiết — OCD AD Mindmap v2025.03

Tài liệu này **đọc kỹ từng box và bảng** trong mindmap *Active Directory* của
Orange Cyberdefense, bản **v2025.03**
([nguồn](https://orange-cyberdefense.github.io/ocd-mindmaps/)), và giải thích cho
mỗi kỹ thuật:

- **Khi nào chạy được** (bạn cần đang ở trạng thái/điều kiện nào).
- **Lệnh cụ thể** — giữ **đúng lệnh trong mindmap**, kèm chú thích biến và bản vá lỗi chính tả.
- **Kết quả ra sao** — output mong đợi, dấu hiệu thành công.
- **Tại sao dùng** — cơ chế đằng sau, mục đích trong chuỗi tấn công.

> Chỉ dùng trong lab / kỳ thi / pentest có ủy quyền. Mindmap tác giả: **Mayfly
> (@M4yFly)**, với Sant0rryu, Viking, Jenaye, Daahtk, Evelyha.

## Mạch chính của mindmap (7 trạng thái — hàng trên cùng)

Mindmap xếp theo **trạng thái bạn đang có**, mỗi cột là một trạng thái; đi từ
trái sang phải = leo dần tới Domain Admin:

```
No Credentials → Valid user (no pw) → Valid Credentials → Low access → Admin access → Domain admin
                                       (cleartext/NT hash/   (Privesc)                 (DA)
                                        kerberos ticket)
        ├─ nhánh ngang: Kerberos Delegation, ADCS, SCCM, MSSQL, NTLM Relay, Coerce, Trusts
```

Mỗi trạng thái, mindmap gắn các box màu:
- **Xanh dương** = hành động/kỹ thuật.
- **Cam/đỏ** = kết quả đạt được (ví dụ "Username", "User + Pass", "Admin",
  "Domain admin", "Kerberos TGT/TGS", "NTLM", "Hash found…").
- Mũi tên = chuyển trạng thái.

## Mục lục

| # | File | Nhánh mindmap tương ứng |
|---|------|--------------------------|
| 00 | [00-ky-hieu-va-cach-doc.md](00-ky-hieu-va-cach-doc.md) | Ký hiệu, legend, biến dùng chung, loại hash & mode |
| 01 | [01-no-credentials.md](01-no-credentials.md) | **No Credentials**: scan, null/guest, poisoning, relay, coerce, known-vulns, PXE |
| 02 | [02-valid-user-no-password.md](02-valid-user-no-password.md) | **Valid user (no password)**: user enum, AS-REP, spray, timeroast |
| 03 | [03-valid-credentials-enum.md](03-valid-credentials-enum.md) | **Valid Credentials**: ldeep/BloodHound, shares, Kerberoast, ASREQroast, GPP, known-vulns-auth |
| 04 | [04-low-access-privesc.md](04-low-access-privesc.md) | **Low access (Privilege escalation)**: AppLocker/UAC bypass, Potato, winPEAS, service exploits (GLPI, Veeam, Exchange…) |
| 05 | [05-kerberos-delegation.md](05-kerberos-delegation.md) | **Kerberos Delegation**: unconstrained, constrained, RBCD, S4U, shadow cred, KrbRelayUp |
| 06 | [06-adcs.md](06-adcs.md) | **ADCS Exploitation**: ESC1–ESC15, Certifried, relay ESC8/ESC11, Pass-the-Cert |
| 07 | [07-credentials-harvesting.md](07-credentials-harvesting.md) | Dump LSASS/SAM/LSA/DPAPI/NTDS, cached, gMSA, LAPS, KeePass, Veeam |
| 08 | [08-lateral-movement.md](08-lateral-movement.md) | PtH, PtT, OverPtH/PTK, psexec/wmiexec/smbexec/atexec/dcomexec, WinRM, RDP |
| 09 | [09-acl-ace-abuse.md](09-acl-ace-abuse.md) | **ACLs/ACEs permissions**: GenericAll/Write, WriteDacl/Owner, group, GPO, DNSAdmins, OU |
| 10 | [10-sccm.md](10-sccm.md) | **SCCM Exploitation**: no-creds PXE, recon, Elevate/Takeover/Creds/Exec |
| 11 | [11-mssql.md](11-mssql.md) | **MSSQL**: enum, xp_cmdshell, impersonate, linked servers, coerce |
| 12 | [12-domain-admin-persistence.md](12-domain-admin-persistence.md) | **Domain admin**: DCSync, Golden/Silver/Diamond/Sapphire, Skeleton, DSRM, Custom SSP, DCShadow, Golden cert |
| 13 | [13-trusts.md](13-trusts.md) | **Trusts**: child↔parent, external, forest, SID history, trust ticket |
| 14 | [14-ntlm-relay.md](14-ntlm-relay.md) | **NTLM Relay / Coerce**: relay tới LDAP/SMB/HTTP/MSSQL/ADCS/WSUS, socks |

## Công cụ viết tắt trong mindmap

| Trong mindmap | Thực tế |
|---------------|---------|
| `nxc` | NetExec (`netexec`) |
| `*.py` (GetUserSPNs.py, secretsdump.py…) | Impacket (trên Kali: `impacket-<tên>`) |
| `ldeep` | LDAP enum toàn diện |
| `Rubeus.exe`, `certify.exe`, `SharpSCCM.exe` | Tool .NET (GhostPack) chạy trên Windows |
| `certipy` | ADCS toolkit (Python, chạy từ Kali) |
| `mimikatz` | Dump creds/ticket (Windows) |
| `bloodhound-python` / `rusthound` / `SharpHound` | Collector cho BloodHound |

## Biến dùng chung (xem file 00)

```bash
export DC=10.10.10.100 DCIP=10.10.10.100 DOMAIN=corp.local \
       USER=alice PASS='Password123!' LHOST=192.168.45.200 IPRANGE=10.10.10.0/24
```

> Lưu ý: tài liệu này **bám sát mindmap** (đôi khi có lệnh của Metasploit `msf>`
> hoặc exploit phá hoại như ZeroLogon). Trong **kỳ thi OSCP**, tránh Metasploit
> (chỉ được dùng 1 lần) và exploit phá hoại — xem ghi chú ⚠️ ở từng chỗ. Bộ tài
> liệu luyện thi theo quy trình nằm ở thư mục [`../../OSCP-AD/`](../../OSCP-AD/README.md).
