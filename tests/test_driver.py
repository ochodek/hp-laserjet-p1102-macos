"""Verify print contracts by decoding the emitted JBIG, including page geometry."""
from pathlib import Path
import re
import os
import subprocess
import tempfile
import unittest
import csv
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def run_filter(raster, options=""):
    return subprocess.run([os.environ.get('P1102_TEST_FILTER', str(ROOT / 'build/rastertop1102')), '1', 'test',
                           'test', '1', options], input=raster, capture_output=True)


def read_image(image):
    data = image.read_bytes()
    header = re.match(rb'P5\s+(\d+)\s+(\d+)\s+3\s', data)
    if not header:
        raise AssertionError('Expected a two-bit printer image')
    width, height = map(int, header.groups())
    return width, height, data[header.end():]


class DriverTests(unittest.TestCase):
    def test_job_options_reach_the_printer_without_changing_the_calibrated_default(self):
        raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'), '8', '0'])
        for options, density, economy, recovery in [('',3,'OFF','OFF'),('pjlDensity=5 EconoMode=True pjlJamRecovery=True',5,'ON','AUTO')]:
            result = run_filter(raster, options)
            self.assertEqual(result.returncode, 0, result.stderr)
            for command in [f'@PJL SET DENSITY={density}', f'@PJL SET ECONOMODE={economy}', f'@PJL SET JAMRECOVERY={recovery}']:
                self.assertIn(command.encode(), result.stdout)
        for options in ['pjlDensity=0','pjlDensity=6','pjlDensity=3x','EconoMode=Maybe','pjlJamRecovery=invalid','P1102ShiftX=-16','P1102ShiftX=69','P1102ShiftY=1']:
            result = run_filter(raster, options)
            self.assertEqual(result.returncode, 1, options)
            self.assertEqual(result.stdout, b'')

    def test_supported_media_and_quality_match_hp_protocol_codes(self):
        media = [1,2,258,282,262,283,265,513,267,514,515,512,260,516,263,273]
        papers = [(595,842,9),(420,595,11),(297,420,70),(612,792,1),(612,1008,5),
                  (522,756,7),(612,936,41),(516,729,0),(553,765,0),(522,737,0),
                  (558,774,0),(284,419,43),(567,420,69),(297,684,20),(279,540,37),
                  (499,709,34),(459,649,28),(312,624,27),(300,500,0)]
        for i,(w,h,code) in enumerate(papers):
            m=media[i % len(media)]; source=4 if i%2 else 7; quality=1 if i%2 else 401
            raster=subprocess.check_output([str(ROOT/'build/raster_fixture'),'8','0','options',str(w),str(h),str(m),str(source),str(quality)])
            result=run_filter(raster)
            self.assertEqual(result.returncode,0,result.stderr)
            with tempfile.TemporaryDirectory() as d:
                path=Path(d)/'job.zjs';path.write_bytes(result.stdout)
                decoded=subprocess.check_output([str(ROOT/'build/zjsdecode'),str(path)],text=True)
            for key,value in [('DMPAPER',code),('DMMEDIATYPE',m),('DMDEFAULTSOURCE',source),('RESOLUTION_Y',600 if quality==1 else 400)]:
                self.assertIn(f'ZJI_{key}, {value} ',decoded)
        for w,h,m,source,quality in [(215,500,1,7,401),(613,500,1,7,401),(300,359,1,7,401),(300,1009,1,7,401),(300,500,999,7,401),(300,500,1,2,401),(300,500,1,7,999)]:
            raster=subprocess.check_output([str(ROOT/'build/raster_fixture'),'8','0','options',str(w),str(h),str(m),str(source),str(quality)])
            self.assertEqual(run_filter(raster).returncode,1)

    def test_spatial_tones_match_hp_on_an_image_not_used_for_calibration(self):
        reference = json.loads((ROOT / 'tests/hp-spatial-reference.json').read_text())
        for color in [0, 3]:
            with self.subTest(color=color), tempfile.TemporaryDirectory() as d:
                raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'),
                                                  '8', str(color), 'verification'])
                result = run_filter(raster)
                self.assertEqual(result.returncode, 0, result.stderr)
                path = Path(d) / 'job.zjs'
                path.write_bytes(result.stdout)
                subprocess.run([str(ROOT / 'build/zjsdecode'), '-d',
                    str(Path(d) / 'page'), str(path)], check=True, stdout=subprocess.DEVNULL)
                images = list(Path(d).glob('page-*.pgm'))
                self.assertEqual(len(images), 1)
                width, height, pixels = read_image(images[0])
                self.assertEqual(width, 2368)
                self.assertEqual(height, 3336)
                self.assertEqual(pixels[:31 * width], b'\x03' * (31 * width))
                self.assertEqual(pixels[(31 + reference['height']) * width:], b'\x03' * (5 * width))
                rows = [pixels[y * width:(y + 1) * width]
                        for y in range(31, 31 + reference['height'])]
                for row in rows:
                    self.assertEqual(row[:15], b'\x03' * 15)
                    self.assertEqual(row[15 + reference['width']:], b'\x03' * (width - 15 - reference['width']))
                pixels = b''.join(row[15:15 + reference['width']] for row in rows)
                self.assertEqual(hashlib.sha256(pixels).hexdigest(), reference['pixels_sha256'])

    def test_fast_print_mode_preserves_printable_area_polarity_and_copies(self):
        for bits, color in [(1, 3), (1, 0), (8, 3), (8, 0)]:
            with self.subTest(bits=bits, color=color), tempfile.TemporaryDirectory() as d:
                raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'),
                                                  str(bits), str(color)])
                result = run_filter(raster)
                self.assertEqual(result.returncode, 0, result.stderr)
                path = Path(d) / 'job.zjs'
                path.write_bytes(result.stdout)
                decoded = subprocess.check_output([str(ROOT / 'build/zjsdecode'),
                    '-d', str(Path(d) / 'page'), str(path)], text=True)
                self.assertEqual(decoded.count('ZJT_START_PAGE,'), 2)
                self.assertEqual(decoded.count('ZJT_END_PAGE,'), 2)
                self.assertIn('ZJT_END_DOC,', decoded)
                self.assertIn('ZJI_DMCOPIES, 1 ', decoded)
                self.assertIn('ZJI_DMCOPIES, 2 ', decoded)
                self.assertEqual(decoded.count('ZJI_DMPAPER, 70 '), 2)
                self.assertEqual(decoded.count('ZJI_DMDEFAULTSOURCE, 7 '), 2)
                # Match HP's FastRes 600 wire mode without changing 600 dpi geometry.
                self.assertEqual(decoded.count('ZJI_RESOLUTION_Y, 400 '), 2)
                self.assertEqual(decoded.count('ZJI_RESOLUTION_X, 600 '), 2)
                self.assertEqual(decoded.count('ZJI_VIDEO_BPP, 2 '), 2)
                # Transport dimensions stay fixed at 1.4 values; only ink moves.
                self.assertEqual(decoded.count('ZJI_VIDEO_X, 2358 '), 2)
                self.assertEqual(decoded.count('ZJI_VIDEO_Y, 3336 '), 2)
                images = sorted(Path(d).glob('page-*.pgm'))
                self.assertEqual(len(images), 2)
                for page, image in enumerate(images):
                    width, height, pixels = read_image(image)
                    self.assertEqual((width, height), (2368, 3336))
                    self.assertEqual(len(pixels), width * height)
                    expected = bytearray(b'\x03' * len(pixels))
                    # Both ends survive unchanged, translated by the calibration padding.
                    for y in [*range(10, 20), 3299 - page]:
                        for x in range(24 + page * 16, 40 + page * 16):
                            expected[(y + 31) * width + x + 15] = 0
                    self.assertEqual(pixels, expected)

    def test_all_gray_tones_match_measured_hp_exposure_populations(self):
        with (ROOT / 'tests/hp-tone-reference.csv').open() as f:
            references = list(csv.DictReader(f))
        self.assertEqual(len(references), 256)
        for color in [0, 3]:
            with self.subTest(color=color), tempfile.TemporaryDirectory() as d:
                raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'),
                                                  '8', str(color), 'ramp'])
                result = run_filter(raster)
                self.assertEqual(result.returncode, 0, result.stderr)
                path = Path(d) / 'job.zjs'
                path.write_bytes(result.stdout)
                subprocess.run([str(ROOT / 'build/zjsdecode'), '-d',
                    str(Path(d) / 'page'), str(path)], check=True, stdout=subprocess.DEVNULL)
                images = sorted(Path(d).glob('page-*.pgm'))
                self.assertEqual(len(images), 1)
                for image in images:
                    width, _, pixels = read_image(image)
                    for reference in references:
                        ink = int(reference['input_ink'])
                        x0, y0 = 115 + ink % 16 * 128, 131 + ink // 16 * 128
                        counts = Counter(pixels[y * width + x]
                                         for y in range(y0 + 16, y0 + 112)
                                         for x in range(x0 + 16, x0 + 112))
                        for exposure in range(4):
                            self.assertEqual(counts[3 - exposure],
                                int(reference[f'level_{exposure}']) * 64, (color, ink, exposure))

    def test_fractional_printable_area_keeps_edge_marks_and_white_padding(self):
        with tempfile.TemporaryDirectory() as d:
            raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'),
                                              '8', '0', 'fractional'])
            result = run_filter(raster)
            self.assertEqual(result.returncode, 0, result.stderr)
            path = Path(d) / 'job.zjs'
            path.write_bytes(result.stdout)
            subprocess.run([str(ROOT / 'build/zjsdecode'), '-d',
                str(Path(d) / 'page'), str(path)], check=True, stdout=subprocess.DEVNULL)
            width, height, pixels = read_image(next(Path(d).glob('page-*.pgm')))
            self.assertEqual((width, height), (2304, 3264))
            expected = bytearray(b'\x03' * len(pixels))
            for y in [0, 3228]:
                for x in [0, 2203]:
                    expected[(y + 31) * width + x + 15] = 0
            for y in [*range(10, 20), 3228]:
                for x in range(24, 40):
                    expected[(y + 31) * width + x + 15] = 0
            self.assertEqual(pixels, expected)

    def test_invalid_fractional_bounds_are_rejected_before_page_encoding(self):
        for kind in ['nan', 'infinity', 'outside', 'inverted']:
            with self.subTest(kind=kind):
                raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'),
                                                  '8', '0', 'fractional-' + kind])
                result = run_filter(raster)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(b'Invalid printable area', result.stderr)
                self.assertEqual(result.stdout, b'')

    def test_incomplete_page_never_reports_a_successful_print(self):
        raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'), '1', '3'])
        result = run_filter(raster[:-100])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'Truncated', result.stderr)
        self.assertNotIn(b'@PJL EOJ', result.stdout)

    def test_empty_job_is_an_error_instead_of_a_blank_success(self):
        self.assertNotEqual(run_filter(b'').returncode, 0)

    def test_untrusted_header_values_are_rejected_without_a_crash(self):
        import struct
        raster = subprocess.check_output([str(ROOT / 'build/raster_fixture'), '1', '3'])
        # CUPS Raster v1: four 64-byte strings followed by native-endian uints.
        # These fields reach allocation, geometry and raster-format validation.
        for field in [4, 5, 6, 7, 8, 9, 10, 21, 24, 25, 29, 30, 32, 33, 34, 35, 36]:
            for value in [0xFFFFFFFF, 0x80000000]:
                damaged = bytearray(raster)
                struct.pack_into('=I', damaged, 4 + 256 + field * 4, value)
                result = run_filter(damaged)
                self.assertEqual(result.returncode, 1, (field, value, result.stderr))


if __name__ == '__main__':
    unittest.main(verbosity=2)
