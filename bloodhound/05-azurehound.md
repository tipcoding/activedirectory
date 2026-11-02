# 05 — AzureHound (Entra ID / Azure)

**AzureHound** thu dữ liệu **Entra ID (Azure AD) & Azure RM** — *không phải* AD
on-prem. Viết bằng Go → chạy trên **Windows / Linux / macOS**. Nạp vào **cùng
BloodHound** (CE hỗ trợ cả node Azure).

> Chỉ liên quan khi mục tiêu có **cloud/hybrid**. OSCP truyền thống hiếm khi cần;
> hữu ích cho pentest hiện đại và chặng hybrid (Azure AD Connect — xem
> [mindmaps/AD-2025.03/12](../mindmaps/AD-2025.03/12-domain-admin-persistence.md)).

## A. Điều kiện

- Một **danh tính Entra** hợp lệ: user+password, hoặc app registration
  (client-id/secret/cert), hoặc refresh token.
- AzureHound đọc qua Microsoft Graph + ARM API → cần Internet tới Azure.

## B. Chạy

```bash
# Bằng username/password
./azurehound -u "user@tenant.onmicrosoft.com" -p "Password123!" list --tenant "tenant.onmicrosoft.com" -o output.json

# Bằng app registration (service principal)
./azurehound -a <app-id> -s "<client-secret>" list --tenant "<tenant-id>" -o output.json
./azurehound --client-id <app-id> --client-cert cert.pem --client-cert-key key.pem list --tenant <tenant-id> -o output.json

# Bằng refresh token (sau khi phish/lấy được)
./azurehound -r "<refresh-token>" list --tenant <tenant-id> -o output.json
```

```powershell
# Windows giống hệt, đổi ./azurehound → .\azurehound.exe
.\azurehound.exe -u user@tenant -p 'pass' list --tenant tenant.onmicrosoft.com -o output.json
```

- **Kết quả:** `output.json` (AzureHound xuất **JSON đơn**, không phải nhiều file
  như SharpHound). Import thẳng vào BloodHound CE.

## C. Thu chọn lọc

```bash
./azurehound -u ... -p ... list users --tenant <t> -o users.json       # chỉ users
./azurehound -u ... -p ... list groups --tenant <t> -o groups.json
./azurehound -u ... -p ... list az-role-assignments --tenant <t> -o roles.json
```

## D. Import & phân tích

- Kéo `output.json` vào BloodHound CE (hoặc Upload File trong UI).
- Node/edge Azure tiêu biểu: `AZUser`, `AZGroup`, `AZApp`, `AZServicePrincipal`,
  `AZRoleAssignment`, edge `AZGlobalAdmin`, `AZOwner`, `AZHasRole`, `AZAddMembers`.
- Query mẫu (CE Cypher):
  ```cypher
  MATCH p=(n)-[:AZGlobalAdmin]->(:AZTenant) RETURN p        // ai là Global Admin
  MATCH p=shortestPath((u:AZUser {owned:true})-[*1..]->(t:AZTenant)) RETURN p
  ```

## E. Lưu ý

- AzureHound version cũng phải khớp dòng BloodHound (tải từ **Download
  Collectors** trong CE để chắc).
- Thu dữ liệu Azure để lại log đăng nhập trên tenant → cân nhắc OPSEC.

→ Phân tích đồ thị chung (on-prem + Azure): [file 06](06-import-va-truy-van.md).
