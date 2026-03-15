export type ImageUrlProbe = (url: string) => Promise<string>;

export async function resolveAccessibleImageUrl(
  imageUrl: string,
  probe: ImageUrlProbe,
) {
  const rawUrl = imageUrl.trim();
  if (!rawUrl) return "";
  try {
    const resolvedUrl = (await probe(rawUrl)).trim();
    return resolvedUrl.length > 0 ? resolvedUrl : rawUrl;
  } catch {
    return rawUrl;
  }
}
