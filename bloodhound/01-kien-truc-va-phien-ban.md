# 01 — Kiến trúc & Phiên bản

## 1. Kiến trúc tổng thể

```
   Collector (SharpHound/python/rust)      →   file .zip (JSON)
        │ LDAP(389/636), SMB(445),              │ kéo-thả / upload
        │ RPC(135), ADWS(9389)                  ▼
        ▼                                 BloodHound UI  ──query──►  Neo4j (graph DB)
   Domain Controller + hosts                (web/desktop)           (bolt 7687)
```

- **Collector** cần: 1 credential domain (user thường là đủ để đọc hầu hết),
  phân giải được tên DC (DNS), và đồng hồ hợp lệ (cho Kerberos nếu dùng `-k`).
- **Neo4j**: cơ sở dữ liệu đồ thị, cổng bolt `7687`, web console `7474`.
- **UI**: nơi bạn chạy query và nhìn đồ thị.

## 2. Hai dòng phiên bản — KHÁC NHAU QUAN TRỌNG

### A. BloodHound **Legacy** (v4.x, "BloodHound Old")

- UI là **ứng dụng desktop Electron** (`bloodhound`), tự kết nối Neo4j bạn chạy.
- Collector: **SharpHound v1.x**, **`bloodhound-python`** (gói
  `bloodhound`/`bloodhound.py`), `rusthound`.
- Đã **ngừng phát triển** (SpecterOps chuyển sang CE) nhưng vẫn phổ biến trong
  nhiều máy lab/HTB cũ và các bản Kali trước đây. Vẫn dùng tốt offline.
- Định dạng JSON: schema cũ.

### B. BloodHound **Community Edition (CE)** — mainline hiện tại

- UI là **web app** chạy qua **Docker Compose** (Postgres + Neo4j + API +
  frontend), truy cập `http://localhost:8080`.
- Collector: **SharpHound v2.x**, **`bloodhound-ce-python`**, **`rusthound-ce`**,
  NetExec `--bloodhound` (hỗ trợ CE).
- Schema JSON mới (có thêm node/edge: ADCS, một số quan hệ mới). **Không** nạp
  được zip của collector Legacy vào CE và ngược lại.
- Có **Cypher search** tích hợp, "Tier Zero", và nhiều query dựng sẵn hơn.

> **Cách nhận biết bạn đang dùng bản nào:**
> - Mở web `:8080`, đăng nhập admin → **CE**.
> - Chạy app desktop `bloodhound`, màn hình login Neo4j → **Legacy**.

## 3. SharpHound v1 vs v2

| | SharpHound **v1** | SharpHound **v2** |
|---|---|---|
| Dành cho | BloodHound Legacy 4.x | BloodHound CE |
| Output | JSON schema cũ | JSON schema CE |
| Cờ phổ biến | `-c All`, `--CollectionMethods` | tương tự, thêm cải tiến ADCS/CE |
| Lấy ở đâu | Release cũ / SharpCollection | Release BloodHound CE |

Dùng **nhầm version collector với UI** là lỗi #1 → đồ thị trống hoặc import fail.
Luôn tải SharpHound **từ đúng release** của UI bạn dùng.

## 4. Bảng tương thích (nạp được vào đâu)

| Collector | → BloodHound Legacy 4.x | → BloodHound CE |
|-----------|:-----------------------:|:---------------:|
| SharpHound v1 | ✅ | ❌ |
| SharpHound v2 | ❌ | ✅ |
| `bloodhound-python` (legacy) | ✅ | ❌ |
| `bloodhound-ce-python` | ❌ | ✅ |
| `rusthound` | ✅ | ⚠️ (tùy bản) |
| `rusthound-ce` | ❌ | ✅ |
| `nxc --bloodhound` | ⚠️ | ✅ (NetExec mới) |

## 5. Neo4j — thành phần nền

- Legacy cần bạn **tự chạy Neo4j** và đặt mật khẩu lần đầu.
- CE **tự quản Neo4j** bên trong Docker Compose; bạn chỉ chạm Neo4j khi muốn gõ
  Cypher nâng cao qua console `:7474`.
- Mật khẩu Neo4j mặc định Legacy: `neo4j/neo4j` → buộc đổi lần đầu.

## 6. Khi nào dùng dòng nào

- **Mới học / theo tài liệu/lab cũ (HTB retired, writeup cũ):** Legacy 4.x thường
  khớp hơn.
- **Môi trường mới / muốn tính năng ADCS, Tier Zero, Cypher tốt:** CE.
- **Thi OSCP:** cả hai đều được; CE tiện vì query ADCS. Quan trọng là **collector
  khớp UI**. Nhiều người giữ **cả hai** để nạp bất kỳ zip nào nhặt được.

→ Cài đặt từng bản: [file 02](02-cai-dat.md).
