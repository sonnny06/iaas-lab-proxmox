# Thiết kế Hệ thống IaaS Thu nhỏ (Proxmox VE)

## 1. Mục tiêu và phạm vi
Mục tiêu của bài lab là triển khai một hạ tầng IaaS thu nhỏ, mô phỏng quá trình cấp phát tài nguyên tự động. Phạm vi giới hạn trong một cụm 1-node (nested virtualization), bao gồm các chức năng tạo máy ảo từ template, quản lý mạng nội bộ, giới hạn tài nguyên và giám sát (Prometheus). Tính năng Live Migration tạm thời không triển khai do giới hạn về hạ tầng vật lý (chỉ có 1 node).

## 2. Môi trường triển khai
*   **Tầng Vật lý (Physical Layer):**
    *   Laptop Windows (Lenovo LOQ)
    *   CPU: [Điền tên CPU của bạn]
    *   RAM: [Điền dung lượng RAM]
    *   Ổ cứng: SSD
*   **Tầng Trung gian (Hypervisor Type 2):**
    *   VMware Workstation Pro
*   **Tầng Ảo hóa IaaS (Hypervisor Type 1 - Nested):**
    *   Máy ảo `pve-lab` chạy Proxmox VE (Phiên bản: [Chạy lệnh `pveversion` trên console để lấy thông số điền vào đây])
    *   Cấu hình cấp phát: 4 vCPU, 6 GB RAM, 60 GB Disk.

## 3. Kiến trúc Hệ thống
*(Chèn hình ảnh sơ đồ từ `docs/diagrams/architecture.png` vào đây sau khi vẽ xong ở Bước 4)*
Hệ thống được thiết kế theo 3 tầng, tách biệt mạng nội bộ của ứng dụng (vmbr1) và cơ sở dữ liệu (vmbr2). Host Proxmox đóng vai trò là router tĩnh để định tuyến giữa hai mạng này.

## 4. Bảng địa chỉ và tài nguyên
*(Mở file `infra/provisioning/catalog.txt` mà bạn vừa copy về, copy nội dung của 4 máy ảo 101, 102, 103, 104 và paste thành định dạng bảng Markdown vào đây. Ví dụ:)*

| VM ID | Tên | IP | vCPU | RAM | Disk | Network |
|---|---|---|---|---|---|---|
| 101 | lab-web-01 | 10.10.1.11 | ... | ... | ... | vmbr1 |
| ... | ... | ... | ... | ... | ... | ... |

## 5. Quyết định thiết kế và Lý do
*   **Chọn Proxmox thay vì DevStack/OpenStack:** Proxmox nhẹ hơn, tiêu tốn ít tài nguyên hơn cho môi trường nested, nhưng vẫn cung cấp đầy đủ các tính năng IaaS cơ bản (KVM, LXC, API, quản lý mạng/storage).
*   **Mô hình Nested Virtualization:** Phù hợp với điều kiện thực hành trên một máy tính cá nhân, dễ dàng snapshot lại toàn bộ trạng thái của cụm IaaS để khôi phục khi cần (disaster recovery).
*   **Sử dụng Host làm Router tĩnh:** Thay vì tạo thêm một VM chuyên dụng làm pfSense/VyOS, việc bật IP forwarding trực tiếp trên Proxmox host giúp tiết kiệm vCPU và RAM, giữ hệ thống nhẹ nhất có thể.
*   **Cơ chế Linked Clone trên LVM-thin:** Các máy ảo được clone từ một template (`tpl-ubuntu2404`) sử dụng LVM-thin provisioning. Điều này giúp quá trình khởi tạo (`provision.sh`) diễn ra cực kỳ nhanh chóng và tiết kiệm tối đa dung lượng ổ cứng thực tế (chỉ lưu trữ các block dữ liệu thay đổi).

## 6. Quota và Giới hạn tài nguyên
Hệ thống sử dụng các tham số giới hạn (cgroups) tích hợp trong Proxmox KVM để mô phỏng cơ chế cấp phát của Cloud Provider. Cụ thể trong script `provision.sh`:
*   Giới hạn CPU cứng (`cpulimit`), đảm bảo VM không chiếm dụng quá số core quy định.
*   Giới hạn RAM tĩnh.
*   Proxmox không hỗ trợ cơ chế Quota cứng cho toàn bộ Resource Pool, do đó việc quản lý dung lượng tổng thuộc trách nhiệm của admin.

## 7. Hạn chế của thiết kế
*   Việc chạy ảo hóa lồng nhau (nested virtualization) làm tăng độ trễ (overhead). Các kết quả đo lường hiệu năng (iperf, fio, ping) chỉ mang tính chất tham khảo tương đối giữa các kịch bản, không phản ánh hiệu năng tuyệt đối của phần cứng.
*   Hệ thống chỉ có 1 node (single-node cluster), do đó không mô phỏng được tính sẵn sàng cao (High Availability) hoặc khả năng chịu lỗi phần cứng ở mức host.