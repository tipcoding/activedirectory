# Active Directory cho OSCP — Tài liệu ôn thi chi tiết

Tài liệu tổng hợp các **đường tấn công (attack path)** Active Directory dựa trên
mindmap của Orange Cyberdefense
([ocd-mindmaps](https://orange-cyberdefense.github.io/ocd-mindmaps/) — bản
*Pentest AD*), được viết lại chi tiết hơn: giải thích **tại sao** kỹ thuật hoạt
động, **lệnh cụ thể** (từ Kali và từ Windows), **cách nhận biết** khi nào dùng,
và **các bài lab** để luyện tập từng kỹ thuật.

> Chỉ dùng trong môi trường lab / kỳ thi / pentest có ủy quyền.

## Cách đọc mindmap OCD

Mindmap được chia theo **trạng thái hiện tại của bạn** (bạn đang có gì trong tay)
→ mỗi nhánh là kỹ thuật để **nâng lên trạng thái tiếp theo**:

```
 Không có gì (No creds)
      │  quét mạng, null session, LLMNR poisoning, relay, AS-REP roast...
      ▼
 Có username (Valid username, no password)
      │  password spraying, AS-REP roasting, username = password...
      ▼
 Có credential hợp lệ (Valid credentials)          ◄── OSCP+ AD set thường bắt đầu ở đây
      │  BloodHound, Kerberoast, share, GPP, ADCS, ACL, delegation...
      ▼
 Local admin trên 1 máy (Admin access)
      │  dump LSASS/SAM/LSA, token, DPAPI → lấy thêm credential
      ▼
 Lateral movement (PtH, PtT, Overpass-the-hash, WinRM, PsExec...)
      ▼
 Domain Admin  →  DCSync / NTDS.dit  →  Persistence (Golden/Silver ticket...)
      ▼
 Trust giữa các domain/forest (ít gặp trong OSCP)
```

## Mục lục

| # | File | Nội dung | Trạng thái trên mindmap |
|---|------|----------|-------------------------|
| 0 | [00-chuan-bi-cong-cu.md](00-chuan-bi-cong-cu.md) | Cài đặt, `/etc/hosts`, `krb5.conf`, đồng bộ giờ, cú pháp các tool | — |
| 1 | [01-khong-co-credential.md](01-khong-co-credential.md) | Quét, null/guest session, LDAP anonymous, user enum, LLMNR/NBT-NS poisoning, NTLM relay, coerce | No creds |
| 2 | [02-co-username.md](02-co-username.md) | Tạo wordlist username, AS-REP roasting, password spraying | Valid username |
| 3 | [03-co-credential-enum.md](03-co-credential-enum.md) | BloodHound, LDAP, PowerView, share, GPP, Kerberoast, MSSQL, ADCS enum | Valid credentials |
| 4 | [04-leo-thang-acl-delegation.md](04-leo-thang-acl-delegation.md) | ACL/ACE abuse, nhóm đặc quyền, LAPS, gMSA, delegation (unconstrained / constrained / RBCD), Shadow Credentials | Privilege escalation trong domain |
| 5 | [05-adcs.md](05-adcs.md) | Active Directory Certificate Services: ESC1–ESC16 phổ biến | Valid credentials → DA |
| 6 | [06-local-admin-dump-credential.md](06-local-admin-dump-credential.md) | Privesc local Windows nhanh, Mimikatz, LSASS, SAM/LSA, DPAPI, cached creds | Admin access |
| 7 | [07-lateral-movement-pivoting.md](07-lateral-movement-pivoting.md) | PtH, PtT, Overpass-the-hash, PsExec/WMI/WinRM/RDP/DCOM, pivoting Ligolo-ng/Chisel | Lateral movement |
| 8 | [08-domain-admin-persistence.md](08-domain-admin-persistence.md) | DCSync, NTDS.dit, Golden/Silver/Diamond ticket, Skeleton key, AdminSDHolder, DSRM | Domain Admin / Persistence |
| 9 | [09-trust.md](09-trust.md) | Child → Parent (ExtraSIDs), forest trust | Trusts |
| 10 | [10-labs.md](10-labs.md) | **Danh sách lab theo từng kỹ thuật** (HTB, PG Practice, THM, PEN-200, GOAD, Vulnlab) + walkthrough tóm tắt | — |
| 11 | [11-quy-trinh-thi-oscp.md](11-quy-trinh-thi-oscp.md) | Checklist khi thi, quy trình assumed-breach, ghi chép & báo cáo | — |
| 12 | [12-cheatsheet.md](12-cheatsheet.md) | Cheatsheet 1 trang: lệnh + hashcat mode | — |

## Quy ước trong tài liệu

| Biến | Ý nghĩa | Ví dụ |
|------|---------|-------|
| `$DC` | IP của Domain Controller | `10.10.10.100` |
| `$DOMAIN` | Tên domain (FQDN) | `corp.local` |
| `$USER` / `$PASS` | Credential đang có | `alice` / `Password123!` |
| `$HASH` | NT hash (32 hex) | `2b576acbe6bcfda7294d6bd18041b8fe` |
| `$LHOST` | IP Kali của bạn (tun0) | `192.168.45.200` |
| `$TARGET` | IP máy mục tiêu bất kỳ | `10.10.10.50` |

Đặt biến một lần cho mỗi bài lab để copy lệnh nhanh:

```bash
export DC=10.10.10.100 DOMAIN=corp.local USER=alice PASS='Password123!' LHOST=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
```

- Trên Kali, Impacket có dạng `impacket-<tên>` (ví dụ `impacket-GetUserSPNs`).
  Nếu cài bằng pip/pipx thì dùng `GetUserSPNs.py`.
- `nxc` = **NetExec** (kế thừa CrackMapExec — cú pháp gần như giống hệt `cme`).
- Lệnh có `PS>` chạy trong PowerShell trên Windows; `C:\>` là cmd.exe.

## Lộ trình học đề xuất (4–6 tuần)

1. **Tuần 1** – File 00 → 03. Làm THM *Attacktive Directory*, HTB *Active*, *Forest*, *Sauna*.
2. **Tuần 2** – File 04, 06, 07. Làm HTB *Support*, *Blackfield*, *Administrator*, PG *Hutch*, *Resourced*.
3. **Tuần 3** – File 05, 08. Làm HTB *Escape*, *Certified*, *EscapeTwo*, PG *Nagoya*, *Vault*.
4. **Tuần 4+** – Chuỗi nhiều máy: PEN-200 Challenge Labs (MedTech, Relia, OSCP A/B/C), HTB *Cicada*, GOAD-Light.
5. Trước thi: đọc lại [11-quy-trinh-thi-oscp.md](11-quy-trinh-thi-oscp.md) và [12-cheatsheet.md](12-cheatsheet.md).
