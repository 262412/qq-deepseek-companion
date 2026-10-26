import { isIP } from 'node:net';

const apiBase = 'https://api.deepseek.com/v1/tools';
const maxSearchResponseBytes = 1_000_000;
const maxFetchResponseBytes = 600_000;

async function readLimitedText(response, maxBytes) {
  if (!response.body) return '';
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > maxBytes) throw new Error('DeepSeek 网页工具响应超过大小限制');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks, size).toString('utf8');
}

async function postDeepSeekTool(name, payload, apiKey, maxBytes) {
  const response = await fetch(`${apiBase}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(30000),
    redirect: 'error',
  });
  const body = await readLimitedText(response, maxBytes);
  if (!response.ok) throw new Error(`DeepSeek ${name} API HTTP ${response.status}`);
  try { return JSON.parse(body); }
  catch { throw new Error(`DeepSeek ${name} API 返回了无效 JSON`); }
}

export function canonicalPublicPageUrl(value) {
  const raw = String(value || '').trim();
  if (!raw || raw.length > 8192) throw new Error('网页地址为空或过长');
  let url;
  try { url = new URL(raw); }
  catch { throw new Error('网页地址格式无效'); }

  const hostname = url.hostname.replace(/^\[|\]$/g, '').replace(/\.$/, '').toLowerCase();
  const localSuffixes = ['.localhost', '.local', '.internal', '.lan', '.home', '.test', '.invalid', '.example'];
  if (url.protocol !== 'https:' || url.username || url.password || url.port && url.port !== '443') {
    throw new Error('只允许不带账号密码的 HTTPS 网页地址');
  }
  if (!hostname.includes('.') || hostname === 'localhost' || isIP(hostname)
    || localSuffixes.some((suffix) => hostname.endsWith(suffix))) {
    throw new Error('网页地址必须是公网域名，不能使用本机、内网或 IP 地址');
  }

  url.hash = '';
  return url.toString();
}

export async function searchWeb(query, apiKey, count = 5) {
  const cleanQuery = String(query || '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
  const normalizedQuery = [...cleanQuery].slice(0, 128).join('');
  if (!normalizedQuery) throw new Error('搜索词不能为空');

  const result = await postDeepSeekTool('search', {
    query: normalizedQuery,
    count: Math.min(5, Math.max(1, Number.isSafeInteger(count) ? count : 5)),
    need_content: false,
  }, apiKey, maxSearchResponseBytes);
  const rows = Array.isArray(result.results) ? result.results : [];
  return {
    query: normalizedQuery,
    results: rows.slice(0, 5).flatMap((row) => {
      try {
        return [{
          title: String(row.title || '').slice(0, 180),
          url: canonicalPublicPageUrl(row.url),
          snippet: String(row.snippet || row.summary || '').slice(0, 700),
          date: typeof row.date === 'string' ? row.date.slice(0, 40) : null,
          authority: Number.isInteger(row.authority) ? row.authority : null,
        }];
      } catch { return []; }
    }),
  };
}

export async function fetchPublicPage(value, apiKey) {
  const url = canonicalPublicPageUrl(value);
  const result = await postDeepSeekTool('fetch', { url }, apiKey, maxFetchResponseBytes);
  const content = String(result.content || '').trim();
  if (!content) throw new Error('网页没有可读取的正文');
  return {
    title: String(result.title || '').slice(0, 180),
    url,
    content: content.slice(0, 12000),
  };
}
