# Active Directory — Tài liệu ôn thi OSCP

Repo tổng hợp các **attack path Active Directory** cho kỳ thi OSCP, dựa trên
mindmap [Orange Cyberdefense](https://orange-cyberdefense.github.io/ocd-mindmaps/)
và viết lại chi tiết: giải thích cơ chế, lệnh cụ thể (Kali + Windows), cách nhận
biết khi nào dùng, và các bài lab để luyện từng kỹ thuật.

> Chỉ dùng trong môi trường lab / kỳ thi / pentest có ủy quyền.

👉 **Bắt đầu tại [`OSCP-AD/README.md`](OSCP-AD/README.md)** — có mục lục đầy đủ và lộ trình học.

👉 Giải thích chi tiết theo mindmap: [`mindmaps/AD-2025.03/README.md`](mindmaps/AD-2025.03/README.md) — đọc kỹ từng box/bảng của OCD AD Mindmap v2025.03, kèm lệnh, điều kiện chạy, kết quả và lý do (có backup file SVG gốc).

👉 BloodHound & SharpHound: [`bloodhound/README.md`](bloodhound/README.md) — kiến trúc, phiên bản (Legacy vs CE), các collector và biến thể, chạy trên từng hệ điều hành, import & truy vấn, khắc phục sự cố.

👉 Giải thích mọi khái niệm AD: [`AD-concepts/README.md`](AD-concepts/README.md) — định nghĩa chi tiết từng khái niệm (forest, Kerberos, ACL, replication, ADCS, credentials…), ví dụ minh hoạ, link tài liệu gốc (Microsoft Learn, RFC, sách).

## Nội dung

| # | File | Chủ đề |
|---|------|--------|
| 0 | [00-chuan-bi-cong-cu.md](OSCP-AD/00-chuan-bi-cong-cu.md) | Chuẩn bị tool, /etc/hosts, krb5.conf, đồng bộ giờ |
| 1 | [01-khong-co-credential.md](OSCP-AD/01-khong-co-credential.md) | Không credential: enum, poisoning, relay, coerce |
| 2 | [02-co-username.md](OSCP-AD/02-co-username.md) | Có username: AS-REP roast, password spraying |
| 3 | [03-co-credential-enum.md](OSCP-AD/03-co-credential-enum.md) | Có credential: BloodHound, Kerberoast, share/GPP, MSSQL |
| 4 | [04-leo-thang-acl-delegation.md](OSCP-AD/04-leo-thang-acl-delegation.md) | ACL/ACE, nhóm đặc quyền, LAPS, gMSA, delegation, shadow creds |
| 5 | [05-adcs.md](OSCP-AD/05-adcs.md) | ADCS ESC1–ESC16 |
| 6 | [06-local-admin-dump-credential.md](OSCP-AD/06-local-admin-dump-credential.md) | Privesc local + dump credential |
| 7 | [07-lateral-movement-pivoting.md](OSCP-AD/07-lateral-movement-pivoting.md) | Lateral movement + pivoting |
| 8 | [08-domain-admin-persistence.md](OSCP-AD/08-domain-admin-persistence.md) | DCSync, NTDS.dit, Golden/Silver ticket |
| 9 | [09-trust.md](OSCP-AD/09-trust.md) | Domain/forest trust |
| 10 | [10-labs.md](OSCP-AD/10-labs.md) | Danh sách lab theo kỹ thuật (HTB/PG/THM/PEN-200/GOAD/Vulnlab) |
| 11 | [11-quy-trinh-thi-oscp.md](OSCP-AD/11-quy-trinh-thi-oscp.md) | Quy trình thi + quản lý thời gian |
| 12 | [12-cheatsheet.md](OSCP-AD/12-cheatsheet.md) | Cheatsheet 1 trang |

---

_App macOS "New File Menu" trước đây ở repo này đã được chuyển sang
[tipcoding/macos-apps-newfilemenu](https://github.com/tipcoding/macos-apps-newfilemenu)._
