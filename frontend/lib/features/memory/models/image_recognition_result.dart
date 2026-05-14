/// 图片识别结果，对应后端 callMultimodalLLM 返回的结构化数据
class ImageRecognitionResult {
  final String textContent;
  final String suggestedTaskTitle;
  final String sceneDescription;
  final String imageUrl;

  const ImageRecognitionResult({
    required this.textContent,
    required this.suggestedTaskTitle,
    required this.sceneDescription,
    required this.imageUrl,
  });
}
