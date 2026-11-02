# 07 — Chọn collector theo tình huống & hệ điều hành

Cây quyết định nhanh để biết **dùng collector nào, phiên bản nào, chạy trên OS nào**.

## A. Cây quyết định

```
Bạn đang đứng ở đâu?
│
├─ Chỉ có Kali/Linux, có creds domain (không đặt chân lên Windows)
│   ├─ UI là CE  → bloodhound-ce-python  (hoặc rusthound-ce / nxc --bloodhound)
│   └─ UI là Legacy → bloodhound-python
│
├─ Đã có shell trên máy Windows domain-joined
│   ├─ Muốn đầy đủ (session/localadmin) → SharpHound (-c All) khớp version UI
│   ├─ AV chặn .exe → SharpHound.ps1 (fileless) hoặc collector từ Kali
│   └─ Muốn cực kín → SOAPHound (ADWS) / AD Explorer snapshot
│
├─ Môi trường rất lớn (chậm/timeout)
│   → rusthound-ce (nhanh) + --ldap-filter, hoặc SharpHound --searchbase chia nhỏ
│
├─ Có sẵn snapshot AD Explorer (.dat)
│   → ADExplorerSnapshot.py
│
└─ Mục tiêu Azure/Entra (cloud/hybrid)
    → AzureHound (Win/Linux/mac)
```

## B. Bảng theo OS bạn đang chạy

| Bạn chạy trên… | Collector khả dụng | Ghi chú |
|----------------|--------------------|---------|
| **Kali/Linux** | bloodhound-ce-python, bloodhound-python, rusthound(-ce), nxc, ADExplorerSnapshot, AzureHound | thu **từ xa** qua LDAP/SMB; không cần Windows |
| **Windows (đã có shell)** | SharpHound.exe/.ps1, SOAPHound, AzureHound | thu **tại chỗ** → nhiều session/localadmin nhất |
| **macOS** | bloodhound-ce-python, rusthound-ce, AzureHound | như Linux |

## C. Theo mục tiêu dữ liệu

| Cần gì | Dùng |
|--------|------|
| Toàn bộ (ACL + session + localadmin) | SharpHound `-c All` (trên Windows) |
| Chỉ cấu trúc thư mục, kín | `-c DCOnly` / SOAPHound / AD Explorer snapshot |
| Ai đăng nhập ở đâu (săn DA) | SharpHound `-c Session --loop` (cần quyền) |
| Nhanh cho domain lớn | rusthound-ce |
| Không chạm máy đích (chỉ LDAP) | bloodhound-ce-python `-c DCOnly`, nxc |
| Azure/Entra | AzureHound |

## D. Theo phiên bản UI (chốt lại)

| UI | Collector hợp lệ |
|----|------------------|
| **BloodHound CE** | SharpHound **v2**, bloodhound-**ce**-python, rusthound-**ce**, nxc (mới), SOAPHound, AzureHound (CE), ADExplorerSnapshot (CE output) |
| **BloodHound Legacy 4.x** | SharpHound **v1**, bloodhound-python, rusthound (legacy) |

## E. Khuyến nghị cho OSCP

1. Trên Kali: giữ **cả** `bloodhound-ce-python` và `bloodhound-python` để nạp
   được bất kỳ dòng nào.
2. Mặc định chạy `bloodhound-ce-python -c All -ns <dc_ip> --zip` ngay khi có creds.
3. Nếu có shell Windows và cần session → chạy thêm `SharpHound.exe -c Session,LocalAdmin`.
4. Luôn **Mark Owned** rồi *Shortest Paths from Owned to Domain Admins*.

## F. Ví dụ đầu-cuối (Kali → CE)

```bash
# 1) Thu
bloodhound-ce-python -d corp.local -u alice -p 'Password123!' -ns 10.10.10.100 -c All --zip
# 2) Chạy UI (nếu chưa)
docker compose up -d           # trong thư mục có docker-compose.yml của CE
# 3) Mở http://localhost:8080 → Upload file *_bloodhound.zip
# 4) Mark Owned 'alice' → Prebuilt: Shortest Paths to Domain Admins from Owned Principals
```
