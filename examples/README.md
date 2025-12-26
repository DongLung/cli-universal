# 繼承 cli-universal 映像檔的範例

這個目錄包含了幾個範例 Dockerfile，示範如何繼承 `cli-universal` 映像檔。

## 範例 1: 簡單繼承 (Dockerfile.child)

保留原有功能，添加自訂套件：

```bash
podman build -f examples/Dockerfile.child -t my-cli:v1 .
podman run --rm my-cli:v1
```

## 範例 2: 應用程式映像檔 (Dockerfile.app)

直接運行應用程式，跳過選單：

```bash
podman build -f examples/Dockerfile.app -t my-app:v1 .
podman run --rm my-app:v1
```

## 範例 3: 開發環境 (Dockerfile.dev)

保留選單但添加開發工具：

```bash
podman build -f examples/Dockerfile.dev -t my-dev:v1 .
podman run --rm -it my-dev:v1
```

## 關鍵設計考量

### 1. ENTRYPOINT 繼承

父映像檔使用 `ENTRYPOINT ["/opt/entrypoint.sh"]`，子映像檔有幾個選項：

- **保留行為**：不設置 ENTRYPOINT/CMD，繼承父映像檔的行為
- **覆蓋 ENTRYPOINT**：`ENTRYPOINT []` 清空，然後設置自己的 CMD
- **保留 ENTRYPOINT，修改 CMD**：保持環境設置，但改變默認命令

### 2. 環境變數控制

可用的環境變數：

```dockerfile
ENV SKIP_WELCOME=1           # 跳過歡迎訊息（尚未實作）
ENV CLI_TOOL=bash            # 設置默認工具：codex/copilot/gemini/bash
ENV DEFAULT_SELECTION=3      # 選單默認選項
ENV MENU_TIMEOUT=10          # 選單超時秒數
```

### 3. 運行時覆蓋

即使子映像檔設置了 ENTRYPOINT，運行時仍可覆蓋：

```bash
# 覆蓋 entrypoint
podman run --rm --entrypoint python3 my-app:v1 --version

# 使用原始 shell
podman run --rm --entrypoint bash my-app:v1 -c 'ls -la'
```

## 版本標籤策略

建議使用以下標籤結構：

```bash
# 建構時打上多個標籤
podman build -t myimage:1.0.0 \
             -t myimage:1.0 \
             -t myimage:1 \
             -t myimage:latest \
             .

# 基於特定版本的父映像檔
FROM cli-universal:python3.12  # 推薦：鎖定特定版本
# FROM cli-universal:latest    # 不推薦：可能會有破壞性變更
```

## 最佳實踐

1. **明確指定父映像檔版本**：使用 `cli-universal:python3.12` 而非 `cli-universal:latest`

2. **保留環境變數**：父映像檔設置的 PATH 和環境變數會被繼承

3. **工作目錄**：父映像檔沒有設置 WORKDIR，子映像檔可以自由設置

4. **用戶權限**：父映像檔使用 root，如需改變請在子映像檔中設置

5. **清理緩存**：安裝套件後記得清理：`dnf clean all` 或 `apt clean`

## 測試繼承行為

```bash
# 測試 1: 無參數（顯示選單或運行默認命令）
podman run --rm my-image:v1

# 測試 2: 直接命令
podman run --rm my-image:v1 python3 --version

# 測試 3: 使用 -c
podman run --rm my-image:v1 -c 'echo $PATH'

# 測試 4: 互動式 shell
podman run --rm -it my-image:v1 bash
```
