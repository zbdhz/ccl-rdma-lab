# ccl-rdma-lab：SimAI + SimCCL + ns-3 软件仿真实验

这是纯 CPU 离散事件仿真：A100、GPU、NIC 均为模型，不需要 CUDA、物理 GPU 或 RDMA 网卡。

## 获取并构建

```bash
git clone https://github.com/zbdhz/ccl-rdma-lab.git
cd ccl-rdma-lab
git submodule update --init SimAI
git -C SimAI submodule update --init SimCCL ns-3-alibabacloud
mkdir -p logs
./build.sh > logs/build.log 2>&1
./run-smoke.sh
```

已验证环境：Ubuntu 22.04、GCC/G++ 11.4、CMake 3.22.1、Python 3、GNU make、Boost 开发头文件。
脚本优先使用 `/usr/bin/cmake`；上游 ns-3 建议不使用 Ninja。
选择性初始化子模块即可，不需要 AICB 或 CLEM。

## 运行

```bash
cd /path/to/ccl-rdma-lab
./run-smoke.sh
```

每次在 `results/smoke-时间-随机串/` 下生成独立结果，并保存当次输入配置。单次设置 180 秒宿主机超时。

## 测试条件

- 2 台虚拟服务器，每台 8 个 A100 模型，共 16 rank，组成一个集合通信组。
- Rail-optimized 拓扑：8 个接入交换机、1 个上层交换机、每服务器 1 个 NVSwitch。
- NIC 和交换机间链路 100 Gbps、每链路传播时延 500 ns；GPU 到 NVSwitch 链路 2400 Gbps、25 ns。
- AllReduce：每 rank 1 MiB 和 4 MiB 两种消息大小。
- SimCCL v2.30 行为模型；禁用 NVLS，保留跨节点 Ring 通信。
- RDMA 后端：CC_MODE=1（DCQCN / Mellanox 风格），开启 ECN 与动态 PFC 阈值，载荷 MTU 9000 B，无随机丢包。
- 仿真单线程，模拟时间上限 1 秒；无 GPU kernel 执行或数据数值正确性验证。

## 文件

- `inputs/allreduce.txt`：通信负载。
- `inputs/topology.txt`：网络拓扑。
- `inputs/SimAI.conf`：网络和拥塞控制参数；文件路径相对运行目录。
- `results/*/ncclFlowModel_EndToEnd.csv`：端到端统计。
- `results/*/ncclFlowModel_detailed_flows.csv`：SimCCL 拆解出的流。
- `results/*/fct.txt`：ns-3 RDMA 完成记录。
- `results/*/run.log`、`SimAI.log`：运行日志。
- `logs/build.log`：首次编译日志。
- `versions.json`：GitHub 源码版本锁定记录。

## 构建

```bash
cd /path/to/ccl-rdma-lab
mkdir -p logs
./build.sh > logs/build.log 2>&1
```

使用 Ubuntu 22.04 的 GCC 11.4 和 `/usr/bin/cmake` 3.22.1，默认 2 个编译任务。通过 `BUILD_JOBS` 可调整并发。
构建脚本按照上游的源码集成方式复制 ASTRA-sim 前端和 SimCCL mock 到 ns-3 后端，
只配置必要模块及其自动依赖，构建 AstraSimNetwork 目标，启用 MTP，禁用额外 examples/tests。
不调用上游向 `/etc/astra-sim` 创建目录的包装脚本。整个实验放在本目录。

Git 子模块指针锁定实际源码版本，`versions.json` 同时记录 Fork 地址、实际 commit 和上游基线。
当前仓库的 `SimAI` 指向 `zbdhz/SimAI` 的 `local-rdma` 分支中的固定提交。
ns-3 锁定版本发布在 `zbdhz/ns-3-alibabacloud` 的 `simai-lab-baseline` 分支；该 Fork 的默认 master 比本实验版本旧，不应直接切换过去。
原有许可证与版权声明保留在各源码仓库中。

本次是软件集成冒烟测试，性能数字是模型输出，尚未经过实机校准。

## 本地修复与验证

原部署机器保留首次未修改上游的运行结果；运行产物和编译日志不纳入 Git。
发现上游 `entry.h` 的发送延迟表采用纳秒，却又乘以 1000 后传入 `Time(...)`；
当前 ns-3 默认分辨率为纳秒且未切换到皮秒，因而启动延迟被放大 1000 倍。
本地改为显式 `NanoSeconds(send_lat)` 并移除多余倍乘。
补丁：`patches/0001-explicit-send-latency-nanoseconds.patch`。修复已提交到锁定的 SimAI 版本，正常克隆后不要重复应用。补丁仅供审阅或移植到未修复的上游版本。

`run-smoke.sh` 清除外部 AS_SEND_LAT 覆盖，使用修复后的默认延迟表。
`verify-results.py` 核对全部流完成、跨服务器流存在、16 个 rank 的收发字节数、
Ring AllReduce 理论通信量，以及冒烟案例时延单位是否异常。
验证通过后生成 `summary.json` 并更新 `results/latest` 链接。
CSV 中时间字段为微秒；FCT 文本的起止/持续时间字段为当前分辨率的纳秒。
无通信的 backward 字段可能出现 `-nan` 带宽（上游对零通信求商），不代表本测试的 forward AllReduce 失败。

## 已完成的测试结果

从个人 Fork 全新克隆、从零编译并运行的验证见 [独立测试报告](docs/fork-verification.md)。

状态：**PASS**。已验证基线见 [`docs/validated-smoke-summary.json`](docs/validated-smoke-summary.json)；本机最近一次成功运行结果写入 `results/latest/summary.json`。

| AllReduce 每 rank 消息大小 | 模型通信耗时 |
|---|---:|
| 1 MiB | 255.894 µs |
| 4 MiB | 275.912 µs |

7,680 条流全部完成，其中 960 条跨服务器；总通信量 157,286,400 B。
每个 rank 发送和接收各 9,830,400 B，符合两次 Ring AllReduce 的理论通信量。
本地工程含构建产物约 820 MiB。没有额外安装系统软件包。

## 开发和同步

详细操作见 [多层子模块开发指南](docs/submodule-development.md)，包含修改目录、分支、构建和逐层推送示例。

仓库关系：`ccl-rdma-lab → SimAI → SimCCL / ns-3-alibabacloud`。
修改子模块前先创建开发分支（例如 `git switch -c my-rdma-change`）。
先在最内层仓库提交并推送，再在父仓库提交子模块指针，最后更新实验仓库的 SimAI 指针。
修改依赖后同步更新 `versions.json`，并重新运行冒烟测试。

例如修改 RDMA 后端后，在 SimAI 中执行 `git add ns-3-alibabacloud` 并提交；
然后回到实验目录执行 `git add SimAI` 并提交。每层都需要单独 push。
如要同步上游，请在各仓库中使用 `upstream` 远程；Git 远程配置是本机设置，不会随 clone 传播。
