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

// Light-blue glass design shared with the Flutter dashboard.
const _style = '''
:root{--ink:#0c2a52;--mute:#0c2a5299;--line:#0c2a5214;--brand:#1d4ed8;--brand2:#0c2a52;
--ok:#15803d;--okbg:#dcfce7;--dlbg:#dbeafe;--glass:linear-gradient(135deg,#ffffffb8,#ffffff66);
--edge:#ffffffd0;--shadow:0 14px 40px #2563eb22}
@media(prefers-color-scheme:dark){:root{--ink:#e6efff;--mute:#e6efff99;--line:#ffffff1a;
--brand:#60a5fa;--brand2:#2563eb;--ok:#86efac;--okbg:#14532d88;--dlbg:#1e3a8a88;
--glass:linear-gradient(135deg,#ffffff1c,#ffffff0a);--edge:#ffffff26;--shadow:0 14px 40px #0006}}
*{box-sizing:border-box;margin:0}
body{min-height:100vh;color:var(--ink);padding:22px 16px 40px;display:flex;justify-content:center;
font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
background:radial-gradient(420px 300px at 0 0,#fff,transparent),
radial-gradient(520px 380px at 100% 100%,#8ec5ff,transparent),
radial-gradient(380px 280px at 80% 0,#c4b5fd88,transparent),
linear-gradient(160deg,#eaf4ff,#cfe5ff 55%,#a9cdff) fixed}
@media(prefers-color-scheme:dark){body{background:radial-gradient(520px 380px at 100% 100%,#1d4ed855,transparent),
radial-gradient(380px 280px at 0 0,#7c3aed44,transparent),linear-gradient(160deg,#0b1730,#0a1228) fixed}}
main{width:100%;max-width:460px}
h1{font-size:46px;line-height:.9;letter-spacing:-.06em;font-weight:900;text-transform:uppercase;padding:8px 4px 18px}
.glass{background:var(--glass);border:1px solid var(--edge);border-radius:24px;
backdrop-filter:blur(20px) saturate(1.5);-webkit-backdrop-filter:blur(20px) saturate(1.5);
box-shadow:inset 0 1px 0 #ffffff80,var(--shadow);padding:18px;margin-bottom:12px}
.app{display:grid;grid-template-columns:56px 1fr;gap:14px;align-items:center}
.icon{width:56px;height:56px;border-radius:15px;display:grid;place-items:center;overflow:hidden;
background:#ffffffaa;border:1px solid #fff;color:var(--brand)}
.icon img{width:100%;height:100%;object-fit:cover}.icon svg{width:30px;height:30px}
.name{font-weight:800;font-size:1.1rem;word-break:break-word}
.sub{color:var(--mute);font-size:.82rem;word-break:break-all}
.act{grid-column:1/3}
.btn{display:flex;align-items:center;justify-content:center;gap:10px;padding:14px;border-radius:14px;
background:linear-gradient(135deg,var(--brand),var(--brand2));color:#fff;font-weight:800;
font-size:1.02rem;text-decoration:none;border:1px solid #ffffff40}
.btn:active{opacity:.85}
.prog{display:none}.prog .t{display:flex;justify-content:space-between;font-size:.8rem;font-weight:700;color:var(--brand)}
.bar{height:8px;border-radius:9px;background:var(--line);margin-top:6px;overflow:hidden}
.bar i{display:block;height:100%;width:0;border-radius:9px;background:linear-gradient(90deg,#3b82f6,#60a5fa);transition:width .4s}
.done{display:none;justify-content:space-between;align-items:center}
.chip{font-size:.78rem;font-weight:800;border-radius:99px;padding:5px 12px;background:var(--okbg);color:var(--ok)}
.again{font-weight:700;font-size:.85rem;color:var(--brand);text-decoration:none}
.open{display:inline-block;font-weight:800;font-size:.85rem;color:#fff;text-decoration:none;border-radius:99px;
padding:6px 14px;background:linear-gradient(135deg,var(--brand),var(--brand2))}
.acts{display:flex;gap:12px;align-items:center}
.app[data-state=downloading] .btn,.app[data-state=done] .btn{display:none}
.app[data-state=downloading] .prog{display:block}
.app[data-state=done] .done{display:flex}
dl{margin-top:6px}
.row{display:flex;justify-content:space-between;gap:16px;padding:10px 0;border-bottom:1px solid var(--line);font-size:.9rem}
.row:last-child{border:0}.row dt{color:var(--mute);flex:none}.row dd{text-align:right;word-break:break-all}
.mono{font-family:ui-monospace,Menlo,monospace;font-size:.74rem}
summary{cursor:pointer;color:var(--mute);font-size:.9rem;margin-top:8px}
.perms{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.perms span{background:var(--line);border-radius:99px;padding:4px 10px;font-size:.72rem;word-break:break-all}
.note{margin-top:14px;color:var(--mute);font-size:.8rem;text-align:center}
.empty{text-align:center;color:var(--mute)}
''';

const _androidIcon =
    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.5l1.7-3a.4.4 0 '
    '00-.7-.4l-1.7 3A10.3 10.3 0 0012 8c-1.8 0-3.5.5-4.9 1.2L5.4 6.2a.4.4 0 '
    '00-.7.4l1.7 3A9.4 9.4 0 002 17h20a9.4 9.4 0 00-4.4-7.5zM8 14.7a.9.9 0 '
    '110-1.8.9.9 0 010 1.8zm8 0a.9.9 0 110-1.8.9.9 0 010 1.8z"/></svg>';

const _downloadIcon =
    '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
    'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M12 3v12m0 0l-5-5m5 5l5-5M5 21h14"/></svg>';

// Polls the server for this phone's downloads and flips each app card between
// "download", "downloading n%" and "downloaded".
const _script = '''
(function(){
  var apps=[].slice.call(document.querySelectorAll('.app[data-file]'));
  if(!apps.length)return;
  function fmt(n){var u=['B','KB','MB','GB'],i=0;while(n>=1024&&i<3){n/=1024;i++}
    return (i?n.toFixed(1):n)+' '+u[i]}
  function paint(list){
    apps.forEach(function(el){
      var f=el.getAttribute('data-file');
      var r=list.filter(function(d){return d.file===f})[0];
      var st=!r?'idle':r.status==='downloading'?'downloading':r.status==='done'?'done':'idle';
      el.setAttribute('data-state',st);
      if(st==='downloading'){
        var p=r.total?Math.min(100,Math.round(r.sent/r.total*100)):0;
        el.querySelector('.bar i').style.width=p+'%';
        el.querySelector('.pct').textContent=p+'% · '+fmt(r.sent)+' / '+fmt(r.total);
      }
    });
  }
  function tick(){
    fetch('/api/downloads?mine=1',{cache:'no-store'}).then(function(r){return r.json()})
      .then(function(j){paint(j.downloads||[])}).catch(function(){});
  }
  apps.forEach(function(el){
    el.querySelector('.btn').addEventListener('click',function(){
      setTimeout(tick,600);setTimeout(tick,1500);
    });
  });
  tick();setInterval(tick,1500);
})();
''';

/// Project name shown instead of the file name.
String _projectName(ApkMeta meta, String fileName) =>
    meta.label ?? meta.packageName ?? fileName;

/// "v1.0.0 (build 1)" or null when the APK has no version info.
String? _versionText(ApkMeta meta) {
  if (meta.versionName == null && meta.versionCode == null) return null;
  return [
    if (meta.versionName != null) 'v${meta.versionName}',
    if (meta.versionCode != null) 'build ${meta.versionCode}',
  ].join(' · ');
}

// Android browsers cannot open a saved file directly; this intent opens the
// system Downloads app where the APK can be tapped to install.
const _openDownloads =
    'intent:#Intent;action=android.intent.action.VIEW_DOWNLOADS;end';

String _page(String title, String body, {bool script = false}) =>
    '<!doctype html><html lang="en"><head>'
    '<meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
    '<meta name="color-scheme" content="light dark">'
    '<meta name="theme-color" content="#cfe5ff">'
    '<title>${_esc(title)}</title><style>$_style</style></head>'
    '<body><main>$body</main>${script ? '<script>$_script</script>' : ''}</body></html>';

/// Simple full-page message (errors, not found).
String renderMessagePage(String title, String message) => _page(
  title,
  '<h1>${_esc(title)}</h1><div class="glass"><p class="sub" '
  'style="font-size:1rem">${_esc(message)}</p></div>',
);

/// One app row/card with the download / progress / downloaded states.
String _appCard({
  required String fileName,
  required int size,
  required ApkMeta meta,
  String? subtitle,
}) {
  final enc = Uri.encodeComponent(fileName);
  final title = _projectName(meta, fileName);
  final icon = meta.iconPng != null
      ? '<img src="/icon/$enc" alt="">'
      : _androidIcon;
  final info = [?_versionText(meta), _formatBytes(size)].join(' · ');
  return '<div class="app" data-file="${_esc(fileName)}" data-state="idle">'
      '<div class="icon">$icon</div>'
      '<div><div class="name">${_esc(title)}</div>'
      '<div class="sub">${_esc(subtitle ?? info)}</div></div>'
      '<div class="act">'
      '<a class="btn" href="/download/$enc" download>$_downloadIcon Download</a>'
      '<div class="prog"><div class="t"><span>Downloading…</span>'
      '<span class="pct"></span></div><div class="bar"><i></i></div></div>'
      '<div class="done"><span class="chip">✓ Downloaded</span>'
      '<div class="acts"><a class="open" href="$_openDownloads">Open</a>'
      '<a class="again" href="/download/$enc" download>Again</a></div></div>'
      '</div></div>';
}

/// The page a phone sees after scanning the QR code for a single APK.
String renderDownloadPage({
  required String fileName,
  required int size,
  required DateTime uploadedAt,
  required ApkMeta meta,
}) {
  final title = _projectName(meta, fileName);

  final rows = <(String, String, bool)>[
    if (meta.packageName != null && meta.packageName != title)
      ('Package', meta.packageName!, false),
    if (meta.versionName != null) ('Version', meta.versionName!, false),
    if (meta.versionCode != null) ('Build', '${meta.versionCode}', false),
    ('Size', _formatBytes(size), false),
    if (meta.minSdk != null)
      ('Requires', '${androidVersionName(meta.minSdk!)} or newer', false),
    if (meta.targetSdk != null)
      ('Target', androidVersionName(meta.targetSdk!), false),
    ('File', fileName, false),
    ('Shared', _formatDate(uploadedAt), false),
    if (meta.sha256 != null) ('SHA-256', meta.sha256!, true),
  ];

  final buf = StringBuffer()
    ..write('<h1>Get the<br>app.</h1>')
    ..write('<div class="glass">')
    ..write(_appCard(fileName: fileName, size: size, meta: meta))
    ..write('</div><div class="glass"><dl>');
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
  buf.write(
    '</div><p class="note">After downloading, open the file and allow '
    '“Install unknown apps” for your browser if Android asks.</p>',
  );
  return _page(title, buf.toString(), script: true);
}

/// One entry of the multi-APK phone page.
class ListItem {
  const ListItem({
    required this.fileName,
    required this.size,
    required this.uploadedAt,
    required this.meta,
  });

  final String fileName;
  final int size;
  final DateTime uploadedAt;
  final ApkMeta meta;
}

/// Phone page listing every staged APK, newest first.
String renderListPage(List<ListItem> items) {
  if (items.isEmpty) {
    return renderMessagePage(
      'Nothing shared yet',
      'No APK is staged on this computer. Ask the sender to drop one in.',
    );
  }
  final buf = StringBuffer()..write('<h1>Get the<br>apps.</h1>');
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final latest = i == 0 && items.length > 1;
    buf.write(
      '<div class="glass">${_appCard(fileName: item.fileName, size: item.size, meta: item.meta, subtitle: [?_versionText(item.meta), _formatBytes(item.size), _formatDate(item.uploadedAt), if (latest) 'Latest'].join(' · '))}<p class="note" style="margin:10px 0 0">'
      '<a class="again" href="/get/${Uri.encodeComponent(item.fileName)}">'
      'Details</a></p></div>',
    );
  }
  buf.write('<p class="note">Tap a file after downloading to install it.</p>');
  return _page('Shared apps', buf.toString(), script: true);
}
