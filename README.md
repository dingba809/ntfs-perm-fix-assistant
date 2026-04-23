# ntfs-perm-fix

用于检查、规划并修复 NTFS 挂载目录权限的 Bash 工具。

## 依赖

- `bash`（建议 4.x+）
- `findmnt`（`util-linux`）
- `mountpoint`（`util-linux`，无该命令时会回退到 `findmnt` 检测）
- `stat`
- `find`
- `chmod`

### 麒麟 V10 / 国产 Linux 桌面环境依赖说明

- 在麒麟 V10、UOS、统信等国产桌面环境中，通常可直接安装：
  - `bash`
  - `util-linux`（提供 `findmnt`、`mountpoint`）
  - `coreutils`（提供 `stat`、`chmod`）
  - `findutils`（提供 `find`）
- 参考命令（按发行版选择）：

```bash
sudo apt install bash util-linux coreutils findutils
```

```bash
sudo dnf install bash util-linux coreutils findutils
```

## 安全说明

- `apply` 会递归修改目标目录及其子项权限，请先使用 `check`/`plan` 评估。
- `apply` 需要 root 权限；可先使用 `apply --dry-run` 预览变更。
- 请确保挂载点来源可信，避免对非预期路径执行修复。

## 命令示例

```bash
bin/ntfs-perm-fix check /mnt/ntfs-data
```

```bash
bin/ntfs-perm-fix plan /mnt/ntfs-data
```

```bash
sudo bin/ntfs-perm-fix apply --dry-run /mnt/ntfs-data
```

```bash
bin/ntfs-perm-fix report
```

## 单文件构建

执行以下命令生成单文件发布包：

```bash
bash scripts/build-single-file.sh
```

- 构建产物路径：`dist/ntfs-perm-fix`
- 如需手动赋予执行权限：

```bash
chmod +x dist/ntfs-perm-fix
```

- 运行示例：

```bash
./dist/ntfs-perm-fix --help
```

## 交互模式

直接运行 `bin/ntfs-perm-fix`（不带子命令）会进入交互模式。

- 主菜单：
  - `1` 扫描 NTFS 挂载点并选择目标盘
  - `2` 查看最近报告（若无报告会给出友好提示）
  - `3` 查看功能说明（面向初级维护人员）
  - `0` 退出
- 目标盘菜单：
  - `[1]` 自动诊断（推荐）
  - `[2]` 查看详细信息（输出挂载检查信息）
  - `[3]` 生成修复建议（等价于 `plan`）
  - `[4]` 执行安全修复（执行前二次确认）
  - `[5]` 执行 dry-run（执行前二次确认）

说明：
- 帮助页会提示“先扫描 NTFS 挂载点”，并建议优先使用“自动诊断”。
- `[4]` 和 `[5]` 都会显示“是否继续”确认提示，输入 `y`/`yes` 才会继续执行。
