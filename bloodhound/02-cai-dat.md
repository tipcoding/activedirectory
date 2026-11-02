# 02 — Cài đặt (theo hệ điều hành)

## A. Kali / Linux — BloodHound CE (Docker Compose, khuyến nghị)

> **Khi nào:** muốn bản mainline, có Docker.

```bash
# 1) Cài Docker + compose plugin
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable --now docker

# 2) Lấy compose file chính thức & chạy
curl -L https://ghst.ly/getbhce -o docker-compose.yml
docker compose up -d
# (hoặc: docker compose -f docker-compose.yml pull && docker compose up -d)

# 3) Lấy mật khẩu admin khởi tạo (in 1 lần trong log)
docker compose logs bloodhound | grep -i "Initial Password"

# 4) Mở UI
xdg-open http://localhost:8080      # đăng nhập admin + mật khẩu ở trên → buộc đổi
```

Quản lý:

```bash
docker compose stop            # dừng
docker compose start           # chạy lại
docker compose down            # xoá container (GIỮ dữ liệu trong volume)
docker compose down -v         # xoá cả dữ liệu (reset sạch)
docker compose pull && docker compose up -d   # nâng cấp
```

> Dữ liệu nằm trong Docker volume → survive restart. Muốn reset hoàn toàn dùng `-v`.

## B. Kali / Linux — BloodHound Legacy 4.x

> **Khi nào:** theo lab/writeup cũ, hoặc không muốn Docker.

```bash
# Cách 1: gói Kali
sudo apt update && sudo apt install -y bloodhound neo4j

# Khởi động Neo4j, đổi mật khẩu lần đầu
sudo neo4j console        # hoặc: sudo neo4j start
#  → mở http://localhost:7474 , login neo4j/neo4j , đổi mật khẩu

# Chạy UI desktop (terminal khác)
bloodhound        # nhập bolt://localhost:7687 + mật khẩu neo4j vừa đặt
```

```bash
# Cách 2: tải binary release (nếu apt lỗi)
# tải BloodHound-linux-x64.zip từ GitHub releases (legacy) → giải nén → ./BloodHound
```

## C. Windows — Legacy (desktop)

```powershell
# 1) Cài Java (OpenJDK 11/17) + Neo4j Community
#    Tải neo4j community zip, giải nén, rồi:
.\bin\neo4j.bat console
# 2) Tải BloodHound-win32-x64.zip (legacy release) → giải nén → BloodHound.exe
```

## D. Windows — CE

Dùng Docker Desktop for Windows rồi `docker compose up -d` như mục A, hoặc chạy
BloodHound CE qua WSL2. Phần lớn pentester chạy CE trên Kali/Linux là tiện nhất.

## E. macOS

```bash
# CE: cài Docker Desktop for Mac → docker compose up -d (như mục A)
# Legacy: brew install neo4j ; chạy neo4j ; tải BloodHound-darwin-x64.zip
brew install --cask docker        # Docker Desktop
brew install neo4j                # cho Legacy
```

## F. Collector — tải về đúng dòng phiên bản

| Collector | Lấy ở đâu | Cài |
|-----------|-----------|-----|
| SharpHound v2 (CE) | Release BloodHound CE (hoặc trong UI: Download Collectors) | copy `.exe`/`.ps1` sang Windows mục tiêu |
| SharpHound v1 (Legacy) | Release SharpHound cũ / SharpCollection | như trên |
| `bloodhound-python` (legacy) | `pipx install bloodhound` | `bloodhound-python` |
| `bloodhound-ce-python` | `pipx install bloodhound-ce` | `bloodhound-ce-python` |
| `rusthound-ce` | GitHub `rusthound-ce` (binary/cargo) | `rusthound-ce` |
| NetExec | `pipx install git+https://github.com/Pennyw0rth/NetExec` | `nxc` |
| AzureHound | GitHub `AzureHound` release (Go binary) | `./azurehound` |

```bash
# Cài collector Python từ Kali
sudo apt install -y bloodhound.py          # bloodhound-python (legacy) trên nhiều bản Kali
pipx install bloodhound-ce                 # bloodhound-ce-python
pipx install netexec
```

> **Trong CE UI** có mục **Download Collectors** → luôn tải đúng SharpHound/AzureHound
> khớp phiên bản server bạn đang chạy. Đây là cách chắc ăn nhất tránh version mismatch.

## G. Kiểm tra sau cài

```bash
# CE chạy?
curl -s http://localhost:8080/ui/login >/dev/null && echo "CE UP"
# Legacy Neo4j chạy?
curl -s http://localhost:7474 >/dev/null && echo "NEO4J UP"
bloodhound-ce-python --help | head
nxc ldap --help | grep -i bloodhound
```

→ Thu thập dữ liệu: SharpHound [file 03](03-sharphound.md); collector đa nền tảng
[file 04](04-collectors-da-nen-tang.md).
