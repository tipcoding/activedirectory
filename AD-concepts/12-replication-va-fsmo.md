# 12 — Replication & FSMO Roles

## Multi-master replication
**Định nghĩa:** mọi DC (trừ RODC) đều **ghi được**; thay đổi ở một DC được **sao
chép** tới các DC khác.

**Chi tiết:** AD dùng mô hình "multi-master loose consistency with convergence"
— thay đổi lan dần, cuối cùng hội tụ. Giao thức: **DRS (Directory Replication
Service)** qua RPC (`DRSUAPI`). **DCSync lạm dụng chính DRSUAPI** (`DRSGetNCChanges`)
để "xin" secret như thể mình là một DC.

*Tài liệu gốc:* [[MS-DRSR] Directory Replication](https://learn.microsoft.com/openspecs/windows_protocols/ms-drsr/),
[AD replication concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts).

---

## USN (Update Sequence Number)
**Định nghĩa:** số đếm tăng dần trên mỗi DC cho mỗi thay đổi. Dùng để biết thay
đổi nào đã sao chép.

**Chi tiết:** mỗi object/attribute có metadata replication (USN, version,
timestamp, **originating DC GUID**). DC theo dõi **high-watermark** (USN cao nhất
đã nhận từ mỗi đối tác) → chỉ kéo thay đổi mới.

---

## High-watermark & Up-to-dateness vector
- **High-watermark:** "tôi đã nhận tới USN bao nhiêu từ DC kia".
- **Up-to-dateness vector (UTDV):** giúp lọc bỏ thay đổi đã biết từ nguồn khác →
  tránh sao chép vòng lặp/trùng.

---

## Conflict resolution
**Định nghĩa:** khi 2 DC sửa cùng thuộc tính đồng thời, giải quyết bằng:
1. **version number** cao thắng; 2. nếu bằng, **timestamp** mới thắng;
3. nếu bằng nữa, **originating DC GUID** lớn thắng.

---

## KCC (Knowledge Consistency Checker)
**Định nghĩa:** tiến trình trên mỗi DC **tự dựng topology replication**
(connection object), tối ưu đường đi dựa trên **site link**.

- **Intra-site:** nhanh, không nén, thông báo thay đổi gần như tức thời.
- **Inter-site:** theo **lịch** (site link cost/interval), **nén** để tiết kiệm băng thông; **ISTG** chọn cầu nối liên site.

*Tài liệu:* [KCC](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts).

---

## Partitions (Naming Contexts) được replicate thế nào
| Partition | Replicate tới |
|-----------|---------------|
| **Schema NC** | mọi DC trong **forest** |
| **Configuration NC** | mọi DC trong **forest** |
| **Domain NC** | mọi DC trong **domain** đó |
| **Partial (GC)** | bản sao read-only mọi domain → các **Global Catalog** |
| **Application partitions** (DNS) | các DC được cấu hình (vd DomainDnsZones) |

---

## FSMO Roles (Flexible Single Master Operations)
**Định nghĩa:** 5 vai trò **chỉ một DC giữ** (single-master) cho các thao tác
không thể làm multi-master. Chia 2 cấp forest / domain.

| Role | Cấp | Nhiệm vụ |
|------|-----|----------|
| **Schema Master** | forest (1) | thay đổi schema |
| **Domain Naming Master** | forest (1) | thêm/bớt domain, application partition |
| **PDC Emulator** | domain (mỗi domain) | đồng bộ thời gian (nguồn NTP), xử lý đổi mật khẩu khẩn, lockout, là mục tiêu GPO mặc định |
| **RID Master** | domain | cấp **pool RID** cho các DC để tạo SID mới |
| **Infrastructure Master** | domain | cập nhật tham chiếu object cross-domain (phantom) |

**Chi tiết an ninh:**
- **PDC Emulator** là nguồn thời gian → tấn công liên quan thời gian (ví dụ cần
  đồng bộ giờ Kerberos) tham chiếu PDC.
- **RID Master**: nếu hỏng, các DC hết RID pool → không tạo được object mới.
- Một số tấn công/khôi phục (vd ZeroLogon) nhắm DC giữ role.

*Ví dụ xem FSMO:*
```powershell
netdom query fsmo
Get-ADForest | select SchemaMaster, DomainNamingMaster
Get-ADDomain | select PDCEmulator, RIDMaster, InfrastructureMaster
```

*Tài liệu gốc:* [FSMO roles](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/fsmo-roles).

---

## Liên hệ tấn công
- **DCSync** = giả làm DC gọi replication → cần quyền DS-Replication (xem
  [file 08](08-uy-quyen-security-descriptor.md), [mindmaps/12](../mindmaps/AD-2025.03/12-domain-admin-persistence.md)).
- **DCShadow** = đăng ký một "DC giả" tạm thời để đẩy thay đổi qua replication mà
  né log thông thường.
