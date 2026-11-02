# 06 — Import dữ liệu & Truy vấn (dùng BloodHound sau khi có zip)

## A. Import

### BloodHound CE
- UI `:8080` → biểu tượng **Upload** (hoặc *Administration → File Ingest*) → chọn
  `.zip` (SharpHound v2 / ce-python / rusthound-ce) hoặc `.json` (AzureHound).
- Chờ xử lý xong (xem tiến trình). Môi trường lớn có thể mất vài phút.

### BloodHound Legacy 4.x
- App desktop → **kéo-thả** file `.zip` vào cửa sổ, hoặc nút **Upload Data**.

```bash
# CE: import bằng dòng lệnh qua API (tùy chọn)
bloodhound-cli (hoặc script dùng /api/v2/file-upload)   # phần lớn dùng UI cho nhanh
```

## B. Mark Owned / High Value

> **Tại sao:** đánh dấu user/máy bạn đã kiểm soát = *Owned* để query "đường từ
> owned tới DA".

- Tìm node (ô search) → chuột phải → **Mark as Owned**.
- Tier Zero / High Value đã được CE gắn sẵn cho nhóm nhạy (Domain Admins, DC…).

## C. Query dựng sẵn (Pre-built)

Trong tab **Analysis** (Legacy) / **Explore → Prebuilt Searches / Cypher** (CE):

- **Find Shortest Paths to Domain Admins**
- **Shortest Paths to Domain Admins from Owned Principals**
- **Find Principals with DCSync Rights**
- **Find Kerberoastable / AS-REP Roastable Users**
- **Shortest Paths to Unconstrained Delegation Systems**
- **Find Computers where Domain Users are Local Admin**
- **Shortest Paths to systems where LAPS is readable**

## D. Cypher tùy biến (hay dùng — gom từ mindmap)

```cypher
// Kerberoastable (loại krbtgt, gMSA/MSA)
MATCH (u:User) WHERE u.hasspn=true AND u.enabled=true
  AND NOT u.objectid ENDS WITH '-502'
  AND NOT COALESCE(u.gmsa,false)=true AND NOT COALESCE(u.msa,false)=true RETURN u

// AS-REP roastable
MATCH (u:User) WHERE u.dontreqpreauth = true AND u.enabled = true RETURN u

// Máy unconstrained delegation (trừ DC)
MATCH (c:Computer {unconstraineddelegation:true}) WHERE NOT c.name STARTS WITH 'DC' RETURN c

// Ai đọc được LAPS
MATCH p=(g:Base)-[:ReadLAPSPassword]->(c:Computer) RETURN p

// Ai điều khiển GPO
MATCH p=((n:Base)-[]->(gp:GPO)) RETURN p

// User/máy là SQL admin
MATCH p=(u:Base)-[:SQLAdmin]->(c:Computer) RETURN p

// Foreign group membership (cross-domain)
MATCH p=(n:User {domain:"CORP.LOCAL"})-[:MemberOf]->(m:Group) WHERE m.domain<>n.domain RETURN p

// Mọi đường từ owned tới Domain Admins
MATCH p=shortestPath((u {owned:true})-[*1..]->(g:Group)) WHERE g.name STARTS WITH 'DOMAIN ADMINS' RETURN p

// Trust giữa các domain
MATCH p=(:Domain)-[:TrustedBy]->(:Domain) RETURN p
```

> CE có ô **Cypher** riêng; Legacy gõ Cypher trong thanh *Raw Query* dưới đáy.

## E. Đọc hướng dẫn khai thác ngay trong BloodHound

- Chuột phải lên **một edge** (ví dụ `GenericAll`) → **Help** → tab **Abuse** →
  BloodHound in **lệnh khai thác cho cả Windows lẫn Linux**. Dùng đó làm nguồn
  chính, rồi tham chiếu chi tiết ở
  [OSCP-AD/04](../OSCP-AD/04-leo-thang-acl-delegation.md) và
  [mindmaps/AD-2025.03/09](../mindmaps/AD-2025.03/09-acl-ace-abuse.md).

## F. Phân tích tự động (báo cáo)

```bash
AD-miner -c -cf Report -u <neo4j_username> -p <neo4j_password>   # sinh báo cáo HTML từ dữ liệu BH
```

## G. Mẹo đọc đồ thị

1. Node bạn kiểm soát → **Mark Owned**.
2. Chạy *Shortest Paths from Owned to Domain Admins*.
3. Xem tab **Outbound Object Control** của node user (user này điều khiển gì).
4. Với mỗi edge trên đường đi → đọc **Abuse** → thực thi → có node mới → **Mark
   Owned** → lặp lại.
