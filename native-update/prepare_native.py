#!/usr/bin/env python3
"""BIMLéman modifications, 2026-10-15, GPL-2.0-or-later like upstream.
Only reviewed v4.11.3 files are patched. Settings/protocol/legal resources stay intact.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', required=True)
    p.add_argument('--logo', required=True)
    p.add_argument('--report', required=True)
    a = p.parse_args()
    root = Path(a.source).resolve()
    # Validate ALL patch anchors before writing anything.
    edits = {
        '3rdparty/ultravnc/winvnc/winvnc/vnckeymap.cpp': [('long childCount = 0L;', ''), ('childCount++;', '')],
        'master/src/SlideshowPanel.cpp': [('Veyon Master – Slideshow', 'BIMLéman View Room – Slideshow')],
        'master/src/ComputerZoomWidget.cpp': [('%1 - Veyon', '%1 - BIMLéman View Room'),
                                            ('%1 - %2 - Veyon', '%1 - %2 - BIMLéman View Room')],
        'plugins/remoteaccess/RemoteAccessWidget.cpp': [('%1 - Veyon Remote Access', '%1 - BIMLéman View Room'), ('%1 - %2 - Veyon Remote Access', '%1 - %2 - BIMLéman View Room')],
        'cmake/modules/PchHelpers.cmake': [('_WIN32_WINNT=0x0602', '_WIN32_WINNT=0x0A00')],
        'core/CMakeLists.txt': [('target_compile_definitions(veyon-core PUBLIC _WIN32_WINNT=0x0602)',
                                 'target_compile_definitions(veyon-core PUBLIC _WIN32_WINNT=0x0A00)')],
        'master/src/MainWindow.ui': [
            ('<string notr="true">Veyon Master</string>', '<string notr="true">BIMLéman View Room</string>'),
            ('<iconset resource="../../core/resources/core.qrc">\n    <normaloff>:/core/icon64.png</normaloff>:/core/icon64.png</iconset>',
             '<iconset resource="../resources/master.qrc">\n    <normaloff>:/master/bimleman-icon.png</normaloff>:/master/bimleman-icon.png</iconset>'),
            ('<string>About Veyon</string>', '<string notr="true">À propos de BIMLéman View Room</string>')],
        'master/resources/master.qrc': [('<file>splash.png</file>', '<file>splash.png</file>\n        <file>bimleman-icon.png</file>')],
        'master/CMakeLists.txt': [('NAME Master', 'NAME Master\n\tDESCRIPTION "BIMLeman View Room"')],
        'master/src/main.cpp': [
            ('#include <QSplashScreen>', '#include <QSplashScreen>\n#include <QIcon>\n#include <QDir>\n#include <QFile>\n#include <QJsonDocument>\n#include <QJsonObject>\n#include <QJsonArray>\n#include "FeatureManager.h"\n#include <QTimer>\n#include <QCryptographicHash>'),
            ('\tsplashScreen.show();', '''\tapp.setWindowIcon( QIcon( QStringLiteral(":/master/bimleman-icon.png") ) );
\tconst bool selfTest = app.arguments().contains(QStringLiteral("--bimleman-self-test"));
\tconst QString evidenceDir = qEnvironmentVariable("BIMLEMAN_EVIDENCE_DIR");
\tif (selfTest && evidenceDir.isEmpty()) { return 2; }
\tsplashScreen.show();
\tapp.processEvents();
\tif (selfTest) {
\t\tQDir().mkpath(evidenceDir);
\t\tsplashScreen.grab().save(evidenceDir + QStringLiteral("/splash.png"));
\t}'''),
            ('\treturn core.exec();', '''\tif (selfTest) {
\t\tQTimer::singleShot(1500, &app, [&]() {
\t\t\tauto window = masterCore.mainWindow();
\t\t\tQJsonObject report;
\t\t\treport.insert(QStringLiteral("title"), window->windowTitle());
\t\t\treport.insert(QStringLiteral("version"), VeyonCore::versionString());
\t\t\treport.insert(QStringLiteral("qt"), QString::fromLatin1(qVersion()));
\t\t\tQJsonArray features;
\t\t\tfor (const auto& feature : VeyonCore::featureManager().features()) { features.append(feature.name()); }
\t\t\treport.insert(QStringLiteral("features"), features);
\t\t\treport.insert(QStringLiteral("iconLoaded"), !window->windowIcon().isNull());
\t\t\treport.insert(QStringLiteral("splashLoaded"), !splashScreen.pixmap().isNull());
\t\t\tfor (const auto& resource : {QStringLiteral("bimleman-icon.png"), QStringLiteral("splash.png")}) {
\t\t\t\tQFile file(QStringLiteral(":/master/") + resource);
\t\t\t\tif (!file.open(QIODevice::ReadOnly)) { app.exit(3); return; }
\t\t\t\treport.insert(resource, QString::fromLatin1(QCryptographicHash::hash(file.readAll(), QCryptographicHash::Sha256).toHex()));
\t\t\t}
\t\t\tconst bool screenshot = window->grab().save(evidenceDir + QStringLiteral("/main-window.png"));
\t\t\tQFile output(evidenceDir + QStringLiteral("/native-smoke.json"));
\t\t\tconst bool ok = output.open(QIODevice::WriteOnly) && output.write(QJsonDocument(report).toJson()) > 0;
\t\t\tapp.exit(ok && screenshot && window->windowTitle() == QStringLiteral("BIMLéman View Room") &&
\t\t\t\t!window->windowIcon().isNull() && !splashScreen.pixmap().isNull() ? 0 : 4);
\t\t});
\t}
\treturn core.exec();''')]
    }
    outputs = {}
    for rel, replacements in edits.items():
        src = (root / rel).read_text(encoding='utf-8')
        for old, new in replacements:
            if src.count(old) != 1:
                raise SystemExit(f'STOP: unrecognized source: {rel}: {old[:70]!r}')
            src = src.replace(old, new, 1)
        notice = 'Modified by BIMLéman View Room on 2026-10-15: native branding/build compatibility.'
        if rel.endswith(('.cpp', '.h')):
            src = '// ' + notice + '\n' + src
        elif rel.endswith(('.ui', '.qrc')):
            comment = '<!-- ' + notice + ' -->\n'
            if src.startswith('<?xml'):
                first, remainder = src.split('\n', 1)
                src = first + '\n' + comment + remainder
            else:
                src = comment + src
        else:
            src = '# ' + notice + '\n' + src
        outputs[rel] = src
    logo = Image.open(a.logo).convert('RGBA')
    icon = Image.new('RGBA', (256, 256), (255, 255, 255, 255))
    thumb = logo.copy()
    thumb.thumbnail((240, 240), Image.Resampling.LANCZOS)
    icon.alpha_composite(thumb, ((256-thumb.width)//2, (256-thumb.height)//2))
    splash = Image.new('RGB', (720, 400), '#ffffff')
    thumb = logo.copy()
    thumb.thumbnail((620, 230), Image.Resampling.LANCZOS)
    splash.paste(thumb, ((720-thumb.width)//2, 24), thumb)
    # Bundled DejaVu Sans supports accents and gives identical typography on Windows/Linux.
    draw = ImageDraw.Draw(splash)
    draw.text((360, 300), 'BIMLéman View Room', fill='#182f40', anchor='mm', font=ImageFont.truetype(str(Path(__file__).parent/'fonts/DejaVuSans.ttf'), size=32))
    draw.text((360, 357), 'Chargement…', fill='#4b6272', anchor='mm', font=ImageFont.truetype(str(Path(__file__).parent/'fonts/DejaVuSans.ttf'), size=20))
    for rel, out in outputs.items():
        (root / rel).write_text(out, encoding='utf-8', newline='\r\n' if rel.startswith('3rdparty/') else '\n')
    icon.save(root / 'master/data/veyon-master.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
    icon.save(root / 'master/resources/bimleman-icon.png')
    splash.save(root / 'master/resources/splash.png')
    files = list(outputs) + ['master/data/veyon-master.ico', 'master/resources/bimleman-icon.png', 'master/resources/splash.png']
    report = {'status': 'PATCHED_NOT_RUNTIME_VALIDATED', 'upstreamVersion': '4.11.3',
              'modified': {rel: hashlib.sha256((root/rel).read_bytes()).hexdigest() for rel in files},
              'legal': 'COPYING, copyright, AboutDialog and all third-party notices preserved',
              'settings': 'Veyon application/organization names and configuration paths unchanged'}
    Path(a.report).parent.mkdir(parents=True, exist_ok=True)
    Path(a.report).write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
