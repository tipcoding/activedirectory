# 04 — Collector đa nền tảng / từ xa (chạy từ Kali)

Khi bạn **không có máy Windows** hoặc không muốn chạm vào máy đích (né AV), thu
dữ liệu BloodHound **từ Kali** chỉ bằng credential domain. Các collector này chạy
trên Linux/macOS/Windows.

> Nhắc lại tương thích: `bloodhound-python`→**Legacy**; `bloodhound-ce-python` /
> `rusthound-ce` / NetExec mới →**CE**.

## A. bloodhound-python (Legacy) & bloodhound-ce-python (CE)

> **Khi nào:** có creds domain, chỉ cần dữ liệu LDAP (+ tùy chọn chạm máy cho session).
> **Tại sao:** nhanh, không cần đặt chân lên Windows.

```bash
# Legacy → nạp vào BloodHound 4.x
bloodhound-python -d $DOMAIN -u $USER -p "$PASS" -ns $NS -c All --zip
# CE → nạp vào BloodHound CE
bloodhound-ce-python -d $DOMAIN -u $USER -p "$PASS" -ns $NS -c All --zip

# Với NT hash thay vì mật khẩu
bloodhound-ce-python -d $DOMAIN -u $USER --hashes :$HASH -ns $NS -c All --zip
# Với Kerberos ticket
export KRB5CCNAME=alice.ccache
bloodhound-ce-python -d $DOMAIN -u $USER -k -no-pass -ns $NS -c All --zip

# DNS trục trặc:
bloodhound-ce-python ... -ns $NS --dns-tcp              # ép DNS qua TCP
bloodhound-ce-python ... -dc $DCFQDN -gc $DCFQDN        # chỉ định DC/Global Catalog
```

Tham số hay dùng:
- `-c All` / `-c DCOnly` / `-c Session,LocalAdmin` — giống SharpHound.
- `-ns <dc_ip>` — name server (gần như luôn cần trong lab).
- `--zip` — đóng gói JSON thành zip để import.
- `-dc`, `-gc` — chỉ định DC / Global Catalog theo FQDN.

- **Kết quả:** `*_bloodhound.zip`. Thiếu `Session`/`LocalAdmin` nếu không chạm máy
  (collector Python lấy session qua SMB/RPC — cần quyền tương ứng).

## B. rusthound / rusthound-ce (Rust — nhanh cho môi trường lớn)

> **Khi nào:** domain lớn, muốn thu nhanh; cross-platform.

```bash
rusthound-ce -d $DOMAIN -u "$USER@$DOMAIN" -p "$PASS" -o output.zip -z
rusthound-ce -d $DOMAIN -u "$USER@$DOMAIN" -p "$PASS" -o output.zip -z \
   --ldap-filter '(objectGuid=*)'                       # lọc để nhẹ/tránh timeout
rusthound  -d $DOMAIN -u "$USER@$DOMAIN" -p "$PASS" -o output.zip -z   # bản legacy
```

- **Kết quả:** zip import vào CE (rusthound-ce) / Legacy (rusthound).

## C. NetExec (nxc --bloodhound)

> **Khi nào:** đã dùng NetExec để enum, muốn thu BloodHound ngay trong 1 lệnh.

```bash
nxc ldap $DC -u $USER -p "$PASS" --bloodhound -c All --dns-server $NS
nxc ldap $DC -u $USER -H $HASH --bloodhound -c All --dns-server $NS
# zip lưu trong ~/.nxc/logs/ (đường dẫn in ra cuối lệnh)
```

- **Kết quả:** zip tương thích CE (NetExec hiện đại). Rất tiện khi đã có phiên nxc.

## D. SOAPHound (né LDAP noisy — qua ADWS)

> **Khi nào:** muốn **tránh truy vấn LDAP ồn ào** bị EDR/monitoring bắt; chạy trên
> Windows, dùng **AD Web Services (cổng 9389)** thay vì LDAP trực tiếp.

```powershell
SOAPHound.exe -c c:\temp\cache.txt --bhdump -o c:\temp\bloodhound-output --autosplit --threshold 900
```

- **Kết quả:** JSON cho BloodHound, nhưng thu qua ADWS → ít bị luật phát hiện LDAP.

## E. ADExplorerSnapshot.py (từ snapshot AD Explorer)

> **Khi nào:** bạn (hoặc client) đã chụp **snapshot bằng Sysinternals AD Explorer**
> (file `.dat`) — cách thu **cực kín** (AD Explorer là công cụ Microsoft ký hợp lệ).

```bash
# Trên Windows: ADExplorer.exe → File → Create Snapshot → lưu snapshot.dat
# Trên Kali: chuyển snapshot .dat sang JSON BloodHound
ADExplorerSnapshot.py snapshot.dat -o output_dir
```

- **Kết quả:** JSON import được. Hạn chế: snapshot LDAP **không có session/local
  admin** (chỉ dữ liệu thư mục).

## F. So sánh nhanh collector từ xa

| Collector | Dòng | Tốc độ | Session/LocalAdmin | Độ kín |
|-----------|------|--------|--------------------|--------|
| bloodhound-python | Legacy | trung bình | có (nếu chạm máy) | trung bình |
| bloodhound-ce-python | CE | trung bình | có | trung bình |
| rusthound-ce | CE | **nhanh** | hạn chế | trung bình |
| nxc --bloodhound | CE | nhanh | có (qua nxc) | trung bình |
| SOAPHound | cả hai | nhanh | hạn chế | **kín (ADWS)** |
| ADExplorerSnapshot | cả hai | n/a | **không** | **rất kín** |

→ Chọn theo tình huống/OS: [file 07](07-chon-collector-theo-tinh-huong.md).
