import 'apk_meta.dart';

String _esc(Object? value) => '$value'
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final text = value.toStringAsFixed(i == 0 ? 0 : 1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} '
      '${units[i]}';
}

String _formatDate(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${months[time.month - 1]} ${time.day}, ${time.year} '
      '${two(time.hour)}:${two(time.minute)}';
}

const _style = '''
:root{--bg:#f3f4fb;--card:#fff;--ink:#1b1b2f;--mute:#6b6e85;--line:#e3e5f1;
--brand:#4f46e5;--brand2:#7c3aed;--chip:#eef0fb}
@media(prefers-color-scheme:dark){:root{--bg:#0b0d13;--card:#14161f;--ink:#eceefb;
--mute:#9a9db5;--line:#262838;--chip:#1c1f2d}}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;background:var(--bg);color:var(--ink);
font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
display:flex;justify-content:center;padding:20px 16px 40px}
main{width:100%;max-width:460px}
.card{background:var(--card);border:1px solid var(--line);border-radius:24px;
padding:24px 20px;box-shadow:0 10px 30px rgba(20,20,60,.08)}
.head{display:flex;gap:16px;align-items:center}
.icon{width:76px;height:76px;border-radius:20px;flex:none;display:grid;
place-items:center;background:linear-gradient(135deg,var(--brand),var(--brand2));
color:#fff;overflow:hidden}
.icon img{width:100%;height:100%;object-fit:cover;background:#fff}
.icon svg{width:40px;height:40px}
h1{font-size:1.3rem;margin:0;letter-spacing:-.02em;word-break:break-word}
.pkg{color:var(--mute);font-size:.85rem;word-break:break-all;margin-top:2px}
.btn{display:flex;align-items:center;justify-content:center;gap:10px;margin:22px 0 6px;
padding:16px;border-radius:16px;background:var(--brand);color:#fff;font-weight:700;
font-size:1.05rem;text-decoration:none}
.btn:active{opacity:.85}
.hint{text-align:center;color:var(--mute);font-size:.8rem;margin:0 0 4px}
dl{margin:18px 0 0;border-top:1px solid var(--line)}
.row{display:flex;justify-content:space-between;gap:16px;padding:11px 0;
border-bottom:1px solid var(--line);font-size:.92rem}
.row dt{color:var(--mute);flex:none}
.row dd{margin:0;text-align:right;word-break:break-all}
.mono{font-family:ui-monospace,Menlo,monospace;font-size:.78rem}
details{margin-top:14px}
summary{cursor:pointer;color:var(--mute);font-size:.9rem}
.perms{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.perms span{background:var(--chip);border-radius:999px;padding:4px 10px;font-size:.72rem;
word-break:break-all}
.note{margin-top:16px;color:var(--mute);font-size:.8rem;text-align:center}
''';

const _androidIcon =
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.5l1.7-3a.4.4 0 '
    '00-.7-.4l-1.7 3A10.3 10.3 0 0012 8c-1.8 0-3.5.5-4.9 1.2L5.4 6.2a.4.4 0 '
    '00-.7.4l1.7 3A9.4 9.4 0 002 17h20a9.4 9.4 0 00-4.4-7.5zM8 14.7a.9.9 0 '
    '110-1.8.9.9 0 010 1.8zm8 0a.9.9 0 110-1.8.9.9 0 010 1.8z"/></svg>';

const _downloadIcon =
    '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
    'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M12 3v12m0 0l-5-5m5 5l5-5M5 21h14"/></svg>';

String _page(String title, String body) =>
    '<!doctype html><html lang="en"><head>'
    '<meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
    '<meta name="color-scheme" content="light dark">'
    '<title>${_esc(title)}</title><style>$_style</style></head>'
    '<body><main>$body</main></body></html>';

/// Simple full-page message (errors, not found).
String renderMessagePage(String title, String message) => _page(
  title,
  '<div class="card"><h1>${_esc(title)}</h1>'
  '<p class="pkg" style="font-size:1rem;margin-top:10px">${_esc(message)}</p></div>',
);

/// The page a phone sees after scanning the QR code.
String renderDownloadPage({
  required String fileName,
  required int size,
  required DateTime uploadedAt,
  required ApkMeta meta,
}) {
  final enc = Uri.encodeComponent(fileName);
  final title = meta.label ?? meta.packageName ?? fileName;

  final rows = <(String, String, bool)>[
    if (meta.versionName != null)
      (
        'Version',
        meta.versionName! +
            (meta.versionCode != null ? ' (${meta.versionCode})' : ''),
        false,
      ),
    ('Size', _formatBytes(size), false),
    if (meta.minSdk != null)
      ('Requires', '${androidVersionName(meta.minSdk!)} or newer', false),
    if (meta.targetSdk != null)
      ('Target', androidVersionName(meta.targetSdk!), false),
    ('File', fileName, false),
    ('Shared', _formatDate(uploadedAt), false),
    if (meta.sha256 != null) ('SHA-256', meta.sha256!, true),
  ];

  final iconHtml = meta.iconPng != null
      ? '<img src="/icon/$enc" alt="">'
      : _androidIcon;

  final buf = StringBuffer()
    ..write(
      '<div class="card"><div class="head"><div class="icon">$iconHtml</div>'
      '<div><h1>${_esc(title)}</h1>',
    );
  if (meta.packageName != null && meta.packageName != title) {
    buf.write('<div class="pkg">${_esc(meta.packageName)}</div>');
  }
  buf
    ..write('</div></div>')
    ..write(
      '<a class="btn" href="/download/$enc" download>$_downloadIcon '
      'Download APK</a>',
    )
    ..write('<p class="hint">${_esc(_formatBytes(size))} · Android package</p>')
    ..write('<dl>');
  for (final (label, value, mono) in rows) {
    buf.write(
      '<div class="row"><dt>${_esc(label)}</dt>'
      '<dd${mono ? ' class="mono"' : ''}>${_esc(value)}</dd></div>',
    );
  }
  buf.write('</dl>');
  if (meta.permissions.isNotEmpty) {
    buf
      ..write(
        '<details><summary>${meta.permissions.length} permissions</summary>'
        '<div class="perms">',
      )
      ..writeAll(
        meta.permissions.map(
          (perm) =>
              '<span>${_esc(perm.replaceFirst('android.permission.', ''))}</span>',
        ),
      )
      ..write('</div></details>');
  }
  buf
    ..write(
      '<p class="note">After downloading, open the file and allow '
      '“Install unknown apps” for your browser if Android asks.</p>',
    )
    ..write('</div>');
  return _page(title, buf.toString());
}
