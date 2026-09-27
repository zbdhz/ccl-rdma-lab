# 修改多层子模块

本工程是四个独立 Git 仓库。每个父仓库记录子模块的一个精确 commit（gitlink），不会把子模块里的未提交修改包含进自己的提交。

```text
ccl-rdma-lab                          实验脚本、输入、版本清单
└── SimAI                            集合通信调度、网络前端
    ├── astra-sim-alibabacloud/       SimAI 内普通源码目录
    ├── SimCCL                      独立 Git 子模块
    └── ns-3-alibabacloud            独立 Git 子模块
```

## 1. 选对源码位置

| 修改目标 | 编辑位置（相对实验工程） | 在哪个仓库提交 |
|---|---|---|
| NCCL 算法选择、channel/chunk、流依赖 | `SimAI/SimCCL/src/mock/v2.30/` | `SimAI/SimCCL` |
| RDMA、拥塞控制、交换机、PFC | `SimAI/ns-3-alibabacloud/simulation/src/point-to-point/model/` | `SimAI/ns-3-alibabacloud` |
| 集合通信调度 | `SimAI/astra-sim-alibabacloud/astra-sim/system/` | `SimAI` |
| 集合通信到 ns-3 的适配 | `SimAI/astra-sim-alibabacloud/astra-sim/network_frontend/ns3/` | `SimAI` |
| 测试配置、构建和运行脚本 | `inputs/`、`build.sh`、`run-smoke.sh` | 实验工程根目录 |

不要直接修改 `SimAI/astra-sim-alibabacloud/extern/network_backend/ns3-interface/`：
这是 `build.sh` 生成的工作副本，重新构建会从上表的源码位置覆盖它。

## 2. 从锁定版本开始建立开发分支

下面假设同时修改 SimCCL 和 ns-3；只改其中一个时，省略另一个子模块对应的命令。
必须在当前锁定的 commit 上创建分支，不要先切换到 Fork 的默认 master。
特别是 ns-3 Fork 的 master 比本实验所用版本旧。

```bash
cd /home/emu/Projects/simai-rdma-lab
BRANCH=feature/rdma-experiment

git status --short
git -C SimAI status --short
git -C SimAI/SimCCL status --short
git -C SimAI/ns-3-alibabacloud status --short

# 分支名需尚未存在；可以换成自己的实验名。
git switch -c "$BRANCH"
git -C SimAI switch -c "$BRANCH"
git -C SimAI/SimCCL switch -c "$BRANCH"
git -C SimAI/ns-3-alibabacloud switch -c "$BRANCH"
```

`git submodule update --init` 后子模块通常处于 detached HEAD，这是锁定版本的正常表现。
在开始编辑前 `git switch -c ...` 即可保留这个基线并开始开发。
已有开发分支时使用 `git switch 分支名`，不要重复 `-c`。

克隆地址保持 HTTPS，方便别人下载。若本机通过 SSH 推送，可配置（每个仓库独立配置）：

```bash
git remote set-url --push origin git@github.com:zbdhz/ccl-rdma-lab.git
git -C SimAI remote set-url --push origin git@github.com:zbdhz/SimAI.git
git -C SimAI/SimCCL remote set-url --push origin git@github.com:zbdhz/SimCCL.git
git -C SimAI/ns-3-alibabacloud remote set-url --push origin git@github.com:zbdhz/ns-3-alibabacloud.git
```

## 3. 修改后先构建和测试

在上表的源码目录修改文件，然后从实验工程根目录执行：

```bash
mkdir -p logs
./build.sh > logs/build.log 2>&1
./run-smoke.sh
```

`build.sh` 会重新复制源码并编译，不需要手动到生成目录改代码。
如果修改了算法、rank 数、消息大小等测试假设，需要相应调整 `verify-results.py` 的断言。
当前验证器专门针对 16 rank 的两个 Ring AllReduce，不适用于任意负载。

当前构建脚本采用覆盖复制，不会自动清除源代码中已删除的旧文件。
若删除或重命名了源码，先把生成目录移走，再执行完整构建，避免残留文件参与编译：

```bash
backend=SimAI/astra-sim-alibabacloud/extern/network_backend/ns3-interface
mv "$backend" "${backend}.backup-$(date +%Y%m%d-%H%M%S)"
./build.sh > logs/build.log 2>&1
./run-smoke.sh
```

这里只移动生成的副本，原始 SimCCL/ns-3 源码仍在子模块目录中。已有的模拟器符号链接会在构建成功后恢复。

## 4. 按“子模块 → SimAI → 实验工程”提交和推送

先提交两个子模块。`add -u` 只包含已跟踪文件的改动；新增文件需要明确 `git add 路径`。
每次 commit 前先审阅暂存差异。未修改的仓库不需要提交。

```bash
# 仍位于实验工程根目录，BRANCH 为上面创建的分支。
git -C SimAI/SimCCL add -u
git -C SimAI/SimCCL diff --cached
git -C SimAI/SimCCL commit -m "Adjust collective flow generation"
git -C SimAI/SimCCL push -u origin "$BRANCH"

git -C SimAI/ns-3-alibabacloud add -u
git -C SimAI/ns-3-alibabacloud diff --cached
git -C SimAI/ns-3-alibabacloud commit -m "Adjust RDMA network model"
git -C SimAI/ns-3-alibabacloud push -u origin "$BRANCH"
```

接着，SimAI 提交两个子模块的新 commit 指针，以及自己被修改的源文件：

```bash
git -C SimAI add SimCCL ns-3-alibabacloud
# 若修改了 SimAI 本身的源码，额外 git -C SimAI add 具体文件路径。
git -C SimAI diff --cached --submodule=log
git -C SimAI commit -m "Use updated collective and RDMA models"
git -C SimAI push -u origin "$BRANCH"
```

最后，更新实验工程的版本清单和 SimAI 指针：

```bash
python3 - <<'PY'
import json
import subprocess
from pathlib import Path
p = Path('versions.json')
versions = json.loads(p.read_text())
for name, path in [('SimAI', 'SimAI'), ('SimCCL', 'SimAI/SimCCL'),
                   ('ns-3-alibabacloud', 'SimAI/ns-3-alibabacloud')]:
    versions[name]['commit'] = subprocess.check_output(
        ['git', '-C', path, 'rev-parse', 'HEAD'], text=True).strip()
    branch = subprocess.check_output(
        ['git', '-C', path, 'branch', '--show-current'], text=True).strip()
    if branch:
        versions[name]['branch'] = branch
    else:
        versions[name].pop('branch', None)
p.write_text(json.dumps(versions, indent=2) + '\n')
PY

git add SimAI versions.json
# 如果修改了测试脚本或输入，再明确 git add 对应文件。
git diff --cached --submodule=log
git commit -m "Pin the validated experiment versions"
git push -u origin "$BRANCH"
```

这四个仓库的分支各自独立。同名只是为了便于管理，不会自动同步。
普通 `git submodule update --init` 使用父仓库记录的 commit；`.gitmodules` 的 `branch` 设置不会覆盖这个锁定版本。
不用为了每个实验修改 `.gitmodules` 的 branch。不要用 `git submodule update --remote` 来复现已发布实验，它会改用远端分支的新版本。

## 5. 在另一目录复现实验分支

```bash
git clone --branch feature/rdma-experiment \
  https://github.com/zbdhz/ccl-rdma-lab.git ccl-rdma-lab-experiment
cd ccl-rdma-lab-experiment
git submodule update --init SimAI
git -C SimAI submodule update --init SimCCL ns-3-alibabacloud
mkdir -p logs
./build.sh > logs/build.log 2>&1
./run-smoke.sh
```

推送子模块必须先于推送父仓库，否则其他人可能拿到无法下载的 commit 指针。
在根目录执行一次 `git commit` 或 `git push` 不会自动提交、推送所有嵌套仓库。
若通过 PR 合并且子模块使用 squash/rebase 导致 commit 改变，需要按合并后的 commit 再更新父仓库指针。
