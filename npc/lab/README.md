# lab —— 旁支实验

数电实验、NVBoard 小 demo 等放在这里，每个实验一个子目录：

```
lab/<name>/
├── Makefile        # 只写参数，然后 include ../common.mk
├── vsrc/*.v        # 顶层模块名与目录名保持一致，例如 shifter
├── csrc/*.cpp      # 每份只有一个 main
├── constr/*.nxdc   # 需要 NVBoard 时放这里
└── build/          # 生成物，被 .gitignore 忽略
```

子项目 Makefile 模板：

```make
TOP       := <name>
VSRC      := $(abspath $(wildcard vsrc/*.v))
CSRC      := $(abspath $(wildcard csrc/*.cpp))
include ../common.mk
```

常用目标（在子目录内执行）：

- `make`        —— 增量构建
- `make sim`    —— 构建并运行，并把结果提交到 `tracer-ysyx` 分支
- `make run`    —— 只运行
- `make clean`  —— 删除本项目的 build/

注意：

- 顶层模块名必须与其它实验不同（生成的 `V<top>.h` 会重名）。
- `common.mk` 用 `wildcard` 收集源文件，一次性收集该子目录下的全部 `.v`/`.cpp`；
  一个子项目只能有一个顶层模块和一个 `main`。
- 主线要交付的东西不要放 lab，放 `npc/vsrc` 和 `npc/csrc`。
