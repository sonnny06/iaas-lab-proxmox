# Ánh xạ Kiến trúc Hệ thống với Mô hình NIST

Dưới đây là bảng phân tích đối chiếu các thành phần trong bài lab IaaS thu nhỏ với Mô hình Kiến trúc Tham chiếu Điện toán Đám mây của NIST (NIST Cloud Computing Reference Architecture):

| Lớp / Thành phần NIST | Thành phần tương ứng trong Lab IaaS |
| :--- | :--- |
| **Service Layer (IaaS)** | Template `tpl-ubuntu2404`, script cấp phát `provision.sh`, danh mục `catalog.txt` mô tả 4 VM (web, app, db, client) được cấp cho người dùng cuối. |
| **Resource Abstraction & Control** | - **Hypervisor:** KVM/QEMU tích hợp trong Proxmox.<br>- **Compute/Memory:** vCPU, vRAM.<br>- **Storage:** Virtual disk định dạng LVM-thin.<br>- **Network:** Virtual network qua các Linux bridge (`vmbr1`, `vmbr2`).<br>- **Resource Control:** Các tham số `cpulimit`, `memory`, giới hạn I/O ổ đĩa.<br>- **Management:** Cơ chế Resource Pool, tính năng Snapshot/Backup.<br>- **Monitoring:** Hệ thống giám sát Prometheus ghi nhận logs và metrics. |
| **Physical Resource Layer** | CPU, RAM, SSD, và Card mạng vật lý của máy tính Windows (Sử dụng VMware Workstation đóng vai trò là lớp trung gian ảo hóa lồng - nested virtualization). |
| **Service Orchestration / Provisioning**| Bộ script bash tự động hóa quá trình cấp phát, quy ước đặt tên định danh VM, quản lý vòng đời khởi tạo và hủy bỏ (provision/deprovision). |
| **Security** | - Xác thực bằng SSH key (Ed25519) thay vì mật khẩu.<br>- Cô lập mạng bằng các bridge nội bộ (`vmbr1` và `vmbr2`).<br>- *Ghi chú:* Hiện tại hệ thống chưa tích hợp Firewall chuyên dụng cho các VM. |

*(Sơ đồ ánh xạ 3 lớp NIST được đính kèm tại `docs/diagrams/nist-mapping.png`)*