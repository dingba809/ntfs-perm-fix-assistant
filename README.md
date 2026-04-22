# ntfs-perm-fix

用于检查、规划并修复 NTFS 挂载目录权限的 Bash 工具。

## 依赖

- `bash`（建议 4.x+）
- `findmnt`（`util-linux`）
- `mountpoint`（`util-linux`，无该命令时会回退到 `findmnt` 检测）
- `stat`
- `find`
- `chmod`

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
