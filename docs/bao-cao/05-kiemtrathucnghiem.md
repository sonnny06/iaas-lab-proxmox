# 5. Thực nghiệm

## 5.1 Môi trường và phương pháp
- Hạ tầng: Proxmox VE (phiên bản 8.x) chạy trong VMware (nested), 2 vCPU, 5876 MB RAM, LVM-thin.
- VM: 4 VM Ubuntu 24.04, 512 MB RAM, đĩa 6 GB; VM gây nhiễu `lab-noisy-01`.
- Công cụ: stress-ng, fio, iperf3, ping, vmstat, Prometheus Node Exporter.
- Mỗi cấu hình chạy 3 lần, báo cáo trung bình ± độ lệch chuẩn.
- Hạn chế: nested virtualization làm số tuyệt đối không phản ánh phần cứng thật, chỉ dùng so sánh tương đối.

## 5.2 Baseline
[Bảng: CPU, I/O, mạng của một VM chạy một mình; nhận xét giới hạn đĩa 100 MB/s có tác dụng.]

## 5.3 Overcommit CPU
[Hình 1 + bảng cpu_overcommit.]
- Nhận xét 1: khi tỷ lệ tăng từ 1:1 lên 2:1, hiệu năng mỗi vCPU giảm còn khoảng 49.6% so với baseline (từ 1566.58 xuống 777.99 ops).
- Nhận xét 2: tổng công việc của cả nhóm VM gần như không đổi (đạt 99.32% so với cấu hình đầu), vì số nhân thật không đổi.
- Nhận xét 3: `steal` trong guest vọt lên 71.23% cho thấy các máy ảo đang phải tranh chấp gay gắt và chờ đợi CPU vật lý cấp phát tài nguyên do cấp vượt quá số nhân thực (nested làm hiện tượng này lộ rõ hơn).

## 5.4 Overcommit RAM
[Hình 2 + bảng ram_overcommit.]
- Mức 0,5×: Hiệu năng cao nhất (Bogo 46639.83 ops), không phát sinh swap (0 MiB) và ping tối đa thấp (74.2 ms). 
- Mức 1,0×: Bắt đầu có dấu hiệu nghẽn, swap-out đạt 1264.13 MiB. 
- Mức 1,5×: swap-out lên 1580.1 MiB, ping lớn nhất nhảy vọt 3788.44 ms, OOM 9 lần, VM sống 3/4.
- Ballooning: RAM guest giảm từ 2115.0 xuống 965.3 MB; swap giảm (còn 1216.47 MiB) so với 1,5× không balloon; rủi ro là ping vẫn giật rất cao (lên 7890.56 ms) và OOM vẫn xảy ra (9 lần) do overhead của tiến trình thu hồi bộ nhớ.
- Kết luận: overcommit RAM chỉ êm khi tổng bộ nhớ thực dùng nhỏ hơn RAM vật lý.

## 5.5 Thin provisioning
[Bảng lvs: tổng dung lượng ảo so với dung lượng pool; ảnh 23, 24.]
- VM clone từ template chỉ chiếm dưới 10-20% dung lượng cấp phát (`Data%`), nhờ linked clone.
- Cấp thử ổ 100 GB lớn hơn pool mà `Data%` của pool không đổi: dung lượng chỉ bị chiếm khi ghi thật[cite: 9]; rủi ro là hết pool nếu mọi VM cùng ghi.

## 5.6 Noisy neighbor
[Hình 3 + bảng noisy_neighbor.]
- CPU: nhiễu làm nạn nhân còn 48.68% so với alone; `cpulimit` khôi phục về 73.4%; `cpuunits` khôi phục về 89.89%.
- I/O: IOPS còn 66.29%, độ trễ p99 tăng khoảng 1362 lần (từ 35.0 lên 47688.0 us); giới hạn `iops_wr`/`mbps_wr` khôi phục vượt mức ban đầu lên 109.49%.
- Mạng: throughput còn 38.95%, độ trễ ping p99 là 6.58 ms (so với 2.69 ms khi alone); giới hạn `rate` khôi phục mạng về 82.38%.

## 5.7 Giải pháp hạn chế (bảng Benchmark)

Bảng dưới đây tổng hợp mức độ suy giảm do tranh chấp tài nguyên đo được trong bài lab, các giải pháp khắc phục (mitigation) tương ứng, và những sự đánh đổi khi áp dụng:

| Vấn đề đo được | Giải pháp | Bằng chứng trong lab | Đánh đổi |
| :--- | :--- | :--- | :--- |
| **Hiệu năng mỗi vCPU giảm khi vCPU:pCPU tăng** | Giữ tỷ lệ vCPU:pCPU thấp cho tải CPU liên tục; dùng tham số `cpuunits` để ưu tiên các VM quan trọng. | Hình 1 (fig1); trạng thái `cpuunits` ở Hình 3 (fig3). | Mật độ VM trên mỗi host thấp hơn; `cpuunits` chỉ có tác dụng khi xảy ra tranh chấp. |
| **VM gây nhiễu chiếm hết CPU** | Dùng `cpulimit` làm trần cứng cho VM gây nhiễu; có thể thêm `affinity` để ghim VM vào nhân riêng vật lý (*chưa kiểm chứng trong lab*). | Trạng thái `cpulimit` ở Hình 3 (fig3); ảnh chụp lệnh `top`. | VM bị chặn (throttle) tài nguyên ngay cả khi host đang rảnh rỗi. |
| **Host swap, độ trễ tăng vọt khi RAM overcommit** | Không cấp tổng RAM vượt RAM thật nếu có tải đồng thời; để swap trên host; dùng cơ chế ballooning với mức tối thiểu hợp lý. | Hình 2 (fig2) - so sánh mức 0.5× với 1.5× (có và không có balloon). | Ballooning phản ứng chậm và mang rủi ro gây lỗi OOM (Out Of Memory) ngay bên trong guest. |
| **Nhiễu I/O đĩa (Noisy neighbor)** | Giới hạn trực tiếp IOPS và băng thông đọc/ghi trên đĩa của VM gây nhiễu. | Trạng thái `limited` ở Hình 3 (fig3) kịch bản I/O. | Các VM có tải I/O hợp lệ/thực sự thỉnh thoảng cũng sẽ bị chậm do chạm trần giới hạn. |
| **Nhiễu băng thông mạng** | Giới hạn thông lượng (`rate`) trên card mạng ảo của máy gây nhiễu. | Trạng thái `limited` ở Hình 3 (fig3) kịch bản mạng. | Giới hạn throughput sẽ áp dụng lên cả các lưu lượng tải hợp lệ. |
| **Cấp phát mỏng (Thin provisioning) hết pool** | Theo dõi sát sao `Data%` của pool; cảnh báo khi đạt ngưỡng (ví dụ 80%); thiết lập quota số VM và dung lượng ở script cấp phát. | Lệnh `lvs` ở Ngày 9; chính sách quota ở Ngày 4. | Đòi hỏi phải có hệ thống và nhân sự giám sát liên tục. |
| **Không phát hiện sớm tranh chấp** | Giám sát các chỉ số `steal`, `swap`, độ trễ bằng Prometheus và đặt sẵn ngưỡng cảnh báo tự động. | Agent Node Exporter đã được cấu hình chạy từ Ngày 5. | Cần phải tốn công cài đặt thêm các công cụ cảnh báo chuyên dụng (như Alertmanager - chưa làm trong lab). |

## 5.8 Thảo luận và hạn chế
- Nested, 1 node, tải tổng hợp, thời gian đo ngắn (45 giây), 3 lần lặp.
- Quan hệ với NIST: private cloud ít lo cô lập hơn public cloud, nhưng noisy neighbor vẫn xảy ra giữa các VM chung host.