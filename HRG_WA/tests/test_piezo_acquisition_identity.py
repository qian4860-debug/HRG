"""Offline regression against false full-text matches and downloaded bytes."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from acquire_piezo_hrg import inspect_pdf, local_identity, title_matches


class AcquisitionIdentity(unittest.TestCase):
    def test_reference_list_is_not_target_fulltext(self):
        title='Theory and Error Analysis of Vibrating-Member Gyroscope'
        self.assertIsNone(local_identity(title,None,Path('US10520331.pdf'),{},'References: '+title,[]))

    def test_short_generic_title_is_not_a_book_match(self):
        self.assertIsNone(local_identity('Shell Theory',None,Path('unrelated_article.pdf'),{},'This model uses Shell Theory.',[]))

    def test_leading_article_does_not_reject_author_manuscript(self):
        self.assertTrue(title_matches('A Coupled Electromechanical Model of an Imperfect Piezoelectric Vibrating Cylinder Gyroscope',
                                     'Coupled electromechanical model of an imperfect piezoelectric vibrating cylinder gyroscope\nPhilip W. Loveday'))

    def test_html_access_page_is_not_pdf(self):
        with self.assertRaises(ValueError):inspect_pdf(b'<html>Access denied</html>')

    def test_every_obtained_record_matches_current_file_hash(self):
        manifest=json.loads((ROOT/'research/piezo_search_20261029/download_manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['records']),32)
        ids=set();paths=set()
        for r in manifest['records']:
            self.assertNotIn(r['id'],ids);ids.add(r['id'])
            if r['status'] not in {'downloaded_fulltext','existing_fulltext'}:
                self.assertNotIn('path',r);continue
            p=Path(r['path']);self.assertTrue(p.is_file())
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),r['sha256'])
            self.assertNotIn(p,paths);paths.add(p)
            info=inspect_pdf(p.read_bytes());self.assertEqual(info['pages'],r['pages'])
            if r['status']=='downloaded_fulltext' and not r['id'] in {'P09','P11'}:
                self.assertTrue(title_matches(r['title'],info['head']),r['id'])


if __name__=='__main__':unittest.main()
