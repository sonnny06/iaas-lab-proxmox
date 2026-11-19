# 6. Biên bản kiểm thử khôi phục

## 6.1 Mục tiêu
Chứng minh dữ liệu và dịch vụ trở lại đúng trạng thái mong đợi sau (a) rollback snapshot
và (b) khôi phục từ backup khi VM bị xóa; ghi thời gian và mức gián đoạn.

## 6.2 Đối tượng và dữ liệu mẫu
- VM: lab-db-01 (ID 103, 10.10.2.11), 1 vCPU, 512 MB, đĩa 6 GB trên LVM-thin.
- Dữ liệu: blob.bin (100 MB ngẫu nhiên) và app.db (SQLite, 20.000 dòng).
- Chuẩn kiểm chứng: sha256 của hai file và `rows_sum 20000 1460000` (file expected.txt, lưu trên host).

## 6.3 Quy trình (mỗi lần, lặp [3] lần)
1. Snapshot khi VM đang chạy. 2. vzdump chế độ snapshot, nén zstd, VM đang chạy.
3. Sửa dữ liệu, kiểm tra checksum phải khác. 4. Rollback, kiểm tra checksum phải khớp.
5. Xóa VM (qm destroy --purge), khôi phục bằng qmrestore, kiểm tra checksum phải khớp.
Gián đoạn đo bằng ping 0,2 giây/gói chạy song song.

## 6.4 Kết quả
[Bảng recovery_results.csv: trung bình ± độ lệch chuẩn cho snapshot, backup, rollback, restore;
 số gói mất; kích thước backup; PASS/FAIL; mutation detected.]

## 6.5 Snapshot khác backup (bằng chứng)
- Trước khi xóa VM: có snapshot snapN, có LV snapshot (ảnh 31).
- Sau khi xóa: không còn snapshot, không còn LV (raw/snapshots_after_destroy_*, lv_after_destroy_*).
- Bản backup (.vma.zst) vẫn còn; hash [..] khớp giữa Proxmox và Windows (ảnh 34).
- Kết luận: snapshot nằm cùng kho lưu trữ với VM nên mất theo VM; backup là file độc lập.

## 6.6 Phân tích
- RTO: rollback [..] s so với restore [..] s (restore chậm hơn [..] lần vì phải ghi lại cả đĩa).
- Gián đoạn: snapshot mất [..] gói (~[..] s), backup mất [..] gói. Backup chạy khi VM còn hoạt động nên gián đoạn nhỏ.
- Chi phí: backup [..] MB cho đĩa 6 GB; vzdump luôn tạo bản đầy đủ.
- Nhất quán: guest agent bật nên hệ thống tệp được đóng băng khi backup.

## 6.7 Migration: chưa thực hiện
Lý do: lab chỉ có 1 node Proxmox. Điều kiện cần để thực hiện (nêu trong 6.8).
Phần khôi phục sang VM mới bằng qmrestore cho thấy ảnh VM mang đi được, nhưng không thay thế migration.

## 6.8 Hạn chế
- "Thảm họa" được giả lập bằng xóa VM, không phải hỏng đĩa vật lý.
- Backup và VM chung một máy vật lý; chỉ ảnh đã chép ra Windows mới độc lập thật.
- Số liệu nested nên chỉ có giá trị so sánh tương đối.
