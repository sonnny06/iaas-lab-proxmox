# Cơ sở Lý thuyết IaaS và Ảo hóa

## 1. Hypervisor Loại 1 và Loại 2
Hypervisor (Trình giám sát máy ảo) là phần mềm tạo và chạy các máy ảo.
*   **Loại 1 (Bare-metal):** Chạy trực tiếp trên phần cứng vật lý, mang lại hiệu suất cao (Ví dụ: Proxmox/KVM, VMware ESXi).
*   **Loại 2 (Hosted):** Chạy trên một hệ điều hành chủ như một ứng dụng thông thường (Ví dụ: VMware Workstation, VirtualBox).
*(Nguồn: Chương 2)*

## 2. Abstraction Tài nguyên (vCPU, vRAM, vDisk, vNIC, Bridge)
Ảo hóa chia sẻ tài nguyên vật lý thành các phiên bản ảo để cấp cho máy ảo. Máy ảo không nhìn thấy phần cứng thật mà chỉ tương tác với các tài nguyên ảo như vCPU (lõi xử lý ảo), vRAM (bộ nhớ ảo), vDisk (ổ cứng ảo), vNIC (card mạng ảo). Bridge hoạt động như một switch ảo trên host để kết nối các vNIC.
*(Nguồn: Chương 2, [33] [CẦN NGUỒN])*

## 3. Template, Clone và Snapshot
*   **Template:** Là một bản sao chuẩn của máy ảo, dùng làm khuôn mẫu để triển khai hàng loạt VM giống nhau một cách nhanh chóng.
*   **Clone:** Hành động tạo ra máy ảo mới từ Template (Linked Clone giúp tạo cực nhanh và tiết kiệm dung lượng do chỉ lưu các block thay đổi, trong khi Full Clone nhân bản hoàn toàn dung lượng ổ đĩa).
*   **Snapshot:** Lưu lại trạng thái của máy ảo tại một thời điểm cụ thể để khôi phục nhanh. Khác với Backup là việc xuất hẳn một bản sao an toàn ra nơi lưu trữ độc lập.
*(Nguồn: Chương 2, [33] [CẦN NGUỒN])*

## 4. Cloud-init
Cloud-init là công cụ tiêu chuẩn thực tế để khởi tạo máy ảo trên nền tảng đám mây. Nó tự động hóa việc thiết lập mạng (IP tĩnh/động), tài khoản người dùng, đẩy SSH key và chạy các lệnh cấu hình trong lần khởi động đầu tiên mà không cần can thiệp thủ công từ console.
*(Nguồn: [33] [CẦN NGUỒN])*

## 5. Thin Provisioning và Overcommit
*   **Thin Provisioning (Cấp phát mỏng):** Hệ thống chỉ tiêu tốn dung lượng lưu trữ vật lý thực tế khi có dữ liệu ghi vào, thay vì cấp phát cứng toàn bộ ngay từ đầu.
*   **Overcommit:** Cho phép cấp phát tổng lượng tài nguyên ảo (RAM, CPU) lớn hơn lượng tài nguyên vật lý thực tế đang có, dựa trên giả định các VM hiếm khi dùng tối đa tài nguyên cùng lúc. Rủi ro là nếu tất cả VM đều tải nặng, host sẽ bị nghẽn hoặc sập.
*(Nguồn: [33] [CẦN NGUỒN])*

## 6. Live Migration
Tính năng di chuyển một máy ảo đang chạy từ host vật lý này sang host vật lý khác mà không làm gián đoạn dịch vụ. Thường yêu cầu hai host phải kết nối vào chung một hệ thống lưu trữ mạng (Shared Storage) và có đường mạng băng thông cao.
*(Nguồn: Chương 2, [33] [CẦN NGUỒN])*

## 7. Đa thuê (Multi-tenancy), Cô lập và Hiệu ứng Noisy Neighbor
Đa thuê là kiến trúc cho phép nhiều khách hàng (tenant) dùng chung một hạ tầng vật lý nhưng dữ liệu phải được cô lập hoàn toàn. Hiệu ứng "Hàng xóm ồn ào" (Noisy Neighbor) xảy ra khi một tenant dùng quá mức tài nguyên chung (I/O đĩa, mạng), làm chậm hệ thống của tenant khác. Các đám mây giải quyết bằng cách áp dụng quota và giới hạn tài nguyên cứng.
*(Nguồn: Chương 2, [33] [CẦN NGUỒN])*

## 8. Kiến trúc NIST Cloud Computing
Kiến trúc tham chiếu của Viện Tiêu chuẩn và Công nghệ Quốc gia Mỹ (NIST) chia hệ sinh thái Đám mây thành 5 tác nhân chính: Cloud Consumer (Người tiêu dùng), Cloud Provider (Nhà cung cấp - nơi chứa Service Layer, Resource Abstraction & Control Layer, Physical Layer), Cloud Auditor (Kiểm toán), Cloud Broker (Môi giới) và Cloud Carrier (Nhà cung cấp mạng).
*(Nguồn: [2] [CẦN NGUỒN])*

## 9. Quota và Giới hạn: Máy ảo (VM) so với Container
Trong IaaS (máy ảo), giới hạn tài nguyên được quản lý bởi Hypervisor thông qua các tiến trình (như QEMU cgroups). Trong Container (như Docker/Kubernetes), giới hạn (requests/limits) được kiểm soát trực tiếp bởi kernel của hệ điều hành Linux chủ. Container nhẹ hơn vì không cần boot OS riêng nhưng mức độ cô lập cứng không bằng VM.
*(Nguồn: [9] [CẦN NGUỒN])*