"""Measure Apple's system-drawn landscape home indicator on selected simulators."""
from pathlib import Path
import argparse
import json
import plistlib
import subprocess
import time
from PIL import Image

OUT = Path(__file__).resolve().parent
BUNDLE = 'com.zippyzen.home-indicator-probe'

def run(*args, **kw):
    return subprocess.run(args, check=True, text=True, **kw)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('models', nargs='+', help='Exact simulator device type names')
    parser.add_argument('--runtime', default='26.5')
    args = parser.parse_args()
    runtimes = json.loads((OUT / 'runtimes.json').read_text())
    runtime = next(r for r in runtimes if r['version'] == args.runtime)
    app = OUT / 'HomeIndicatorProbe.app'
    app.mkdir(exist_ok=True)
    info = dict(CFBundleIdentifier=BUNDLE, CFBundleExecutable='HomeIndicatorProbe',
                CFBundleName='HomeIndicatorProbe', CFBundlePackageType='APPL',
                CFBundleVersion='1', CFBundleShortVersionString='1.0', MinimumOSVersion='17.0',
                UIDeviceFamily=[1, 2], UIRequiresFullScreen=True, UILaunchScreen={},
                UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes': False, 'UISceneConfigurations': {}},
                UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'])
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    if not (app / 'HomeIndicatorProbe').exists() or (app / 'HomeIndicatorProbe').stat().st_mtime < (OUT / 'HomeIndicatorProbe.swift').stat().st_mtime:
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
        run('swiftc', '-parse-as-library', '-target', 'arm64-apple-ios17.0-simulator', '-sdk', sdk,
            '-module-cache-path', '/tmp/td-home-indicator-swift-cache', str(OUT / 'HomeIndicatorProbe.swift'),
            '-o', str(app / 'HomeIndicatorProbe'))
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(app))
    measurements_path = OUT / 'measurements.json'
    for name in args.models:
        dtype = next(d for d in runtime['supportedDeviceTypes'] if d['name'] == name)
        device = subprocess.check_output(['xcrun', 'simctl', 'create', 'TD Home Indicator ' + name,
                                          dtype['identifier'], runtime['identifier']], text=True).strip()
        print('Measuring', name, device, flush=True)
        try:
            run('xcrun', 'simctl', 'boot', device)
            run('xcrun', 'simctl', 'bootstatus', device, '-b', stdout=subprocess.DEVNULL)
            run('xcrun', 'simctl', 'install', device, str(app), stdout=subprocess.DEVNULL)
            run('xcrun', 'simctl', 'launch', device, BUNDLE, stdout=subprocess.DEVNULL)
            container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', device, BUNDLE, 'data'], text=True).strip())
            geometry_path = container / 'Documents/geometry.json'
            for _ in range(80):
                if geometry_path.exists():
                    break
                time.sleep(0.25)
            geometry = json.loads(geometry_path.read_text())
            slug = name.replace(' ', '-').replace('/', '-') + '-iOS-' + args.runtime
            (OUT / (slug + '-geometry.json')).write_text(json.dumps(geometry, indent=2))
            screenshot = OUT / (slug + '.png')
            run('xcrun', 'simctl', 'io', device, 'screenshot', str(screenshot), stdout=subprocess.DEVNULL)
            im = Image.open(screenshot).convert('RGB')
            threshold = 230
            # simctl saves the native portrait framebuffer even when UIKit and
            # the home indicator are in landscape. Normalize for measurement.
            rotation = 0
            if im.width < im.height:
                rotation = 90 if geometry.get('interfaceOrientation', 3) == 3 else 270
                im = im.transpose(Image.Transpose.ROTATE_90 if rotation == 90 else Image.Transpose.ROTATE_270)
            w, h = im.size
            assert w > h, (name, im.size, geometry)
            # A white probe makes both an active and dimmed system pill darker
            # than the background. Ignore rounded screen corners at the far sides.
            points = [(x, y) for y in range(h - round(30 * w / geometry['window'][0]), h)
                      for x in range(w//5, w*4//5) if max(im.getpixel((x, y))) < threshold]
            assert points, ('No visible home indicator', name, str(screenshot))
            x0, x1 = min(x for x, y in points), max(x for x, y in points) + 1
            y0, y1 = min(y for x, y in points), max(y for x, y in points) + 1
            assert abs((x0 + x1) / 2 - w / 2) < 2, (name, x0, x1, w)
            assert y1 - y0 < 12 * geometry['scale'], (name, y0, y1)
            row = dict(model=name, runtime=args.runtime, geometry=geometry,
                       screenshot=screenshot.name, normalizedScreenshotSize=[w, h], rotationDegrees=rotation,
                       threshold=threshold, indicatorPixelBounds=[x0, y0, x1, y1],
                       indicatorWidthPoints=(x1-x0)*geometry['window'][0]/w, screenWidthFraction=(x1-x0)/w)
            measurements = json.loads(measurements_path.read_text()) if measurements_path.exists() else []
            measurements = [m for m in measurements if (m['model'], m['runtime']) != (name, args.runtime)] + [row]
            measurements_path.write_text(json.dumps(measurements, indent=2) + '\n')
            print(json.dumps(row), flush=True)
        except Exception as error:
            print('MEASUREMENT ERROR', name, repr(error), flush=True)
        finally:
            subprocess.run(['xcrun', 'simctl', 'shutdown', device], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(['xcrun', 'simctl', 'delete', device], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == '__main__':
    main()
