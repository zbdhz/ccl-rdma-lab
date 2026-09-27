# Fork 版本独立构建验证

验证日期：2026-09-27。结果：**PASS**。

从 `https://github.com/zbdhz/ccl-rdma-lab.git` 全新克隆，在独立目录初始化 SimAI、SimCCL 和 ns-3 子模块，
从零编译后运行 `./run-smoke.sh`。没有复制原部署目录的二进制、动态库或构建缓存。
本报告和开发指南是在验证完成后添加的文档，不影响下面列出的已测试源代码版本。

| 仓库 | 实际验证 commit |
|---|---|
| ccl-rdma-lab | `7c6cd1d8382479295776fc74cd9dc7f754e01f92` |
| SimAI | `0154b87f3a855726a83bcbf0847cb9549cc62724` |
| SimCCL | `fd7cd57d16f9bd42e3ccb70911c977e18ec294b9` |
| ns-3-alibabacloud | `3e0c7c1bfbbe9f77890ddcf5e5b9c79fc6dd7437` |

所有初始化的子模块都从 zbdhz 的 Fork 获取，commit 与 `versions.json` 完全一致。
未初始化、不参与此次测试的 AICB 和 CLEM 不在验证范围内。

## 环境和执行

- Ubuntu 22.04，GCC/G++ 11.4，系统 CMake 3.22.1。
- 纯 CPU 仿真，debug 构建，2 个编译任务，仿真 1 线程。
- 执行仓库中的 `build.sh` 和 `run-smoke.sh`。
- 构建存在上游代码警告，但没有编译或链接错误。
- 已通过动态链接检查：执行文件及 ns-3 动态库均来自新克隆目录。
- 构建和运行后，四个 Git 工作区都保持干净。

原部署机器的独立验证目录：`/home/emu/Projects/ccl-rdma-lab-verify-KM32br`。
构建日志：该目录下的 `logs/build.log`；动态库记录：`logs/runtime-linkage.txt`。
这些大体积产物和本机日志没有提交到 GitHub。

## 仿真结果

2 台虚拟服务器，每台 8 rank，NIC 100 Gbps，执行 Ring AllReduce。

| 每 rank 消息大小 | 集合通信耗时 |
|---|---:|
| 1 MiB | 255.894 µs |
| 4 MiB | 275.912 µs |

- 生成与完成的通信流：均为 7,680 条。
- 跨服务器通信流：960 条。
- 总通信量：157,286,400 B。
- 每个 rank 发送、接收各 9,830,400 B，符合两次 Ring AllReduce 的理论通信量。
- `summary.json` 与仓库内 `docs/validated-smoke-summary.json` 完全一致。

机器可读报告见 [fork-verification.json](fork-verification.json)。

这验证了当前锁定版本在此环境下可以获取、编译并完成指定的联合仿真案例。
不代表所有算法、协议、拥塞场景或其他操作系统都已验证，也不代表性能模型已经过实机校准。
开发时从当前锁定 commit 建立分支，不要直接改用 ns-3 Fork 较旧的 master。
