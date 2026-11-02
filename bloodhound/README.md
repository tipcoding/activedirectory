# BloodHound & SharpHound — Hướng dẫn chi tiết

Thư mục này giải thích **toàn bộ hệ sinh thái BloodHound**: cách hoạt động, các
**phiên bản** (Legacy vs Community Edition), các **collector** (SharpHound và các
biến thể), và **chạy trên hệ điều hành nào** cho từng tình huống.

> Dùng trong lab / pentest có ủy quyền. BloodHound chỉ **thu thập & phân tích**
> dữ liệu AD — bản thân nó không khai thác; nó chỉ ra *đường đi* để bạn khai thác.

## BloodHound là gì (giải thích nhanh)

BloodHound gồm 2 phần:
1. **Collector** (SharpHound / bloodhound-python / rusthound…): kết nối LDAP +
   SMB + RPC tới domain, thu user, nhóm, ACL, session, quyền admin local, GPO,
   trust, ADCS, SCCM… rồi xuất ra file **JSON (đóng trong .zip)**.
2. **UI + Graph DB** (Neo4j): nạp zip, dựng **đồ thị quan hệ**, cho bạn hỏi
   "đường ngắn nhất từ user tôi kiểm soát tới Domain Admins?" bằng **Cypher**.

Mỗi quan hệ là một **edge** (cạnh): `MemberOf`, `AdminTo`, `GenericAll`,
`HasSession`, `CanRDP`, `AllowedToDelegate`, `ReadLAPSPassword`… Khai thác từng
edge xem [OSCP-AD/04](../OSCP-AD/04-leo-thang-acl-delegation.md) và
[mindmaps/AD-2025.03/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md).

## Mục lục

| # | File | Nội dung |
|---|------|----------|
| 01 | [01-kien-truc-va-phien-ban.md](01-kien-truc-va-phien-ban.md) | Kiến trúc, **Legacy (4.x) vs Community Edition**, Neo4j, SharpHound v1 vs v2, bảng tương thích |
| 02 | [02-cai-dat.md](02-cai-dat.md) | Cài đặt theo OS: Kali/Linux, Windows, macOS, Docker Compose |
| 03 | [03-sharphound.md](03-sharphound.md) | **SharpHound** (.exe/.ps1): phiên bản, CollectionMethods, chạy trên Windows, OPSEC/loop |
| 04 | [04-collectors-da-nen-tang.md](04-collectors-da-nen-tang.md) | Collector **đa nền tảng / từ xa**: bloodhound-python, bloodhound-ce-python, rusthound(-ce), nxc, SOAPHound, ADExplorerSnapshot |
| 05 | [05-azurehound.md](05-azurehound.md) | **AzureHound** cho Entra ID / Azure |
| 06 | [06-import-va-truy-van.md](06-import-va-truy-van.md) | Import dữ liệu, Mark Owned, query dựng sẵn + Cypher tùy biến, pathfinding |
| 07 | [07-chon-collector-theo-tinh-huong.md](07-chon-collector-theo-tinh-huong.md) | **Ma trận quyết định**: OS nào / tình huống nào → dùng collector + phiên bản nào |
| 08 | [08-khac-phuc-su-co-va-opsec.md](08-khac-phuc-su-co-va-opsec.md) | Lỗi thường gặp (version mismatch, DNS, clock, môi trường lớn) + OPSEC/detection |

## Tóm tắt nhanh: collector nào chạy ở đâu (OS matrix)

| Collector | Ngôn ngữ | Chạy TRÊN OS | Thu dữ liệu của | Dùng cho phiên bản |
|-----------|----------|--------------|------------------|--------------------|
| **SharpHound.exe** | C#/.NET | **Windows** (domain-joined hoặc có creds) | AD on-prem | CE (v2) & Legacy (v1) tùy build |
| **SharpHound.ps1** | PowerShell wrapper | **Windows** | AD on-prem | như trên |
| **bloodhound-python** | Python | **Linux/macOS/Windows** (từ xa) | AD on-prem | **Legacy 4.x** |
| **bloodhound-ce-python** | Python | **Linux/macOS/Windows** (từ xa) | AD on-prem | **CE** |
| **rusthound / rusthound-ce** | Rust | **Linux/macOS/Windows** (từ xa) | AD on-prem | Legacy / CE |
| **nxc ... --bloodhound** | Python (NetExec) | **Linux** (từ xa) | AD on-prem | CE (và legacy) |
| **SOAPHound.exe** | C#/.NET | **Windows** | AD (qua ADWS, né LDAP noisy) | CE/Legacy |
| **ADExplorerSnapshot.py** | Python | **Linux** (xử lý snapshot) | từ file .dat của Sysinternals AD Explorer | Legacy/CE |
| **AzureHound** | Go | **Windows/Linux/macOS** | **Entra ID / Azure** (không phải on-prem) | CE (và legacy) |

> ⚠️ **Quy tắc vàng về tương thích:** collector và UI phải **cùng dòng phiên bản**.
> SharpHound v2 / `bloodhound-ce-python` / `rusthound-ce` → **BloodHound CE**.
> SharpHound v1 (cũ) / `bloodhound-python` → **BloodHound Legacy 4.x**. Nạp sai
> dòng sẽ lỗi import hoặc đồ thị trống. Chi tiết [file 01](01-kien-truc-va-phien-ban.md).

## Biến dùng chung (như các thư mục khác)

```bash
export DC=10.10.10.100 DCFQDN=DC01.corp.local DOMAIN=corp.local \
       USER=alice PASS='Password123!' NS=10.10.10.100
```
