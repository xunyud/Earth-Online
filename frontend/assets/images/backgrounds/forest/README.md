# 森林背景资源获取指南

## 推荐资源来源

### 方案 1：OpenGameArt.org（推荐）

**搜索关键词**：
- "parallax forest background"
- "pixel art forest layers"
- "2d platformer forest"

**推荐资源包**：

1. **Parallax Forest Background** (CC0 许可)
   - 链接：https://opengameart.org/content/parallax-forest-background
   - 包含多层视差背景
   - 分辨率：适合 1920x1080

2. **Forest Parallax Background** (CC-BY 3.0)
   - 链接：https://opengameart.org/content/forest-parallax-background
   - 4-5 层视差图层
   - 泰拉瑞亚风格

3. **Pixel Art Forest Pack**
   - 链接：https://opengameart.org/content/forest-pack
   - 包含树木、灌木、山脉素材

### 方案 2：itch.io

**搜索关键词**：
- "terraria forest background"
- "pixel forest parallax free"

**推荐资源**：
- https://itch.io/game-assets/free/tag-forest
- 筛选条件：Free + Pixel Art

---

## 所需图层

请下载以下 4 个图层（PNG 格式）：

1. **sky.png** - 天空层（静态背景）
   - 建议尺寸：1920x1080
   - 内容：蓝天 + 云朵

2. **far.png** - 远景层（视差速度 0.2x）
   - 建议尺寸：1920x1080 或更宽
   - 内容：远处的山脉/树林轮廓

3. **mid.png** - 中景层（视差速度 0.5x）
   - 建议尺寸：2400x1080 或更宽
   - 内容：中距离的树木

4. **near.png** - 前景层（视差速度 1.0x）
   - 建议尺寸：3000x1080 或更宽
   - 内容：近处的灌木、草丛

---

## 文件放置位置

下载后，将文件重命名并放置到：
```
frontend/assets/images/backgrounds/forest/
├── sky.png
├── far.png
├── mid.png
└── near.png
```

---

## 许可证要求

- **CC0**：无需署名，可自由使用
- **CC-BY 3.0/4.0**：需要在 `frontend/CREDITS.md` 中注明作者

---

## 临时占位图（可选）

如果暂时找不到合适资源，可以使用纯色占位：
- sky.png：浅蓝色 (#87CEEB)
- far.png：深绿色半透明 (#228B22, 30% opacity)
- mid.png：绿色半透明 (#32CD32, 50% opacity)
- near.png：亮绿色半透明 (#98FF98, 70% opacity)

使用在线工具生成：https://placeholder.com/ 或 Photoshop/GIMP

---

## 下一步

1. 访问推荐链接下载资源
2. 将图片放入 `frontend/assets/images/backgrounds/forest/` 目录
3. 通知我已完成，我将继续实现视差滚动背景组件
