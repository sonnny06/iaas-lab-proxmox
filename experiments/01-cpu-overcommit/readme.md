# Ngày 8: Thí nghiệm Overcommit CPU

## Mục tiêu
Đánh giá mức độ suy giảm hiệu năng của vCPU và sự thay đổi về tổng năng lực xử lý của toàn bộ hệ thống ảo hóa (Proxmox/KVM) khi cấp phát số lượng vCPU cho các máy ảo vượt quá số lượng nhân CPU vật lý thực tế (pCPU) ở nhiều tỷ lệ khác nhau.

## Môi trường và Cấu hình
- **Host (pve-lab):** 2 nhân vật lý (`nproc = 2`), RAM ~6GB.
- **Máy ảo (VM):** Sử dụng 2 VM (ID `101` và `102`) trên tổng số 4 VM của bài lab, các VM khác được giữ ở trạng thái tắt.
- **Cấu hình thử nghiệm (CLIST):** Lần lượt thử nghiệm cấp 1 vCPU và 2 vCPU cho mỗi máy ảo.
    - Cấu hình 1 (1 vCPU/VM): 2 VM x 1 = 2 vCPU. Tỷ lệ vCPU:pCPU = **1:1**.
    - Cấu hình 2 (2 vCPU/VM): 2 VM x 2 = 4 vCPU. Tỷ lệ vCPU:pCPU = **2:1**.
    - *(Cấu hình 4 vCPU/VM bị lược bỏ do Proxmox giới hạn số vCPU tối đa không vượt quá tổng số pCPU của hệ thống cho một máy ảo đơn lẻ)*.

## Lệnh thực thi
Toàn bộ quá trình được tự động hóa bằng script bash chạy trên hệ điều hành Proxmox:
```bash
bash /root/iaas-lab/experiments/01-cpu-overcommit/cpu_overcommit.sh