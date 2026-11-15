# Ngày 9: Thí nghiệm Overcommit RAM và Thin Provisioning

## Mục tiêu
Đánh giá mức độ ảnh hưởng đến hiệu năng hệ thống (swap, độ trễ mạng, tình trạng OOM - Out of Memory) khi tổng dung lượng RAM cấp phát cho các máy ảo vượt quá dung lượng RAM thực tế của host. Thử nghiệm hiệu quả của cơ chế `ballooning` trong việc thu hồi RAM. Đồng thời, xác minh cơ chế cấp phát mỏng (Thin Provisioning) thông qua LVM-thin trên Proxmox.

## Môi trường và Cấu hình
- **RAM Host (`H`):** 5876 MB (Khoảng 6GB).
- **Máy ảo (VM):** Sử dụng toàn bộ 4 VM của bài lab (ID `101`, `102`, `103`, `104`).
- **Cấu hình thử nghiệm (CFGS):** Thử nghiệm 4 mức tỷ lệ tổng RAM cấp / RAM Host:
    - `0.5:off`: Cấp 0.5x RAM Host, **tắt** ballooning.
    - `1.0:off`: Cấp 1.0x RAM Host, **tắt** ballooning.
    - `1.5:off`: Cấp 1.5x RAM Host, **tắt** ballooning.
    - `1.5:balloon`: Cấp 1.5x RAM Host, **bật** ballooning.

## Lệnh thực thi
Kịch bản tự động được thực thi bằng lệnh:
```bash
bash /root/iaas-lab/experiments/02-ram-overcommit/ram_overcommit.sh