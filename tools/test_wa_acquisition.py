"""Offline boundary checks for citation matching and false-fulltext rejection."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import acquire_wa_citations as a


class Page:
    def __init__(self,text):self.text=text
    def extract_text(self):return self.text


class Reader:
    def __init__(self,pages):self.pages=[Page(x) for x in pages]


class AcquisitionBoundaries(unittest.TestCase):
    def test_split_doi(self):
        self.assertEqual(a.dois('https://doi.org/10.1016/j. measurement.2021.109704.'),['10.1016/j.measurement.2021.109704'])

    def test_fullwidth_doi(self):
        self.assertEqual(a.dois('ＤＯＩ：１０．１１９７７／j.issn.1004-2474.2023.04.002'),['10.11977/j.issn.1004-2474.2023.04.002'])

    def test_additional_publisher_journal_codes(self):
        self.assertIn('https://mdpi-res.com/d_attachment/actuators/actuators-14-00275/article_deploy/actuators-14-00275.pdf',a.candidates(dict(doi='10.3390/act14060275')))
        self.assertIn('https://mdpi-res.com/d_attachment/mathematics/mathematics-09-00292/article_deploy/mathematics-09-00292.pdf',a.candidates(dict(doi='10.3390/math9030292')))

    def test_title_not_author_only(self):
        self.assertLess(a.title_score('Coriolis Vibratory Gyros','Lynch D D. Vibratory gyro analysis by the method of averaging'),.8)

    def test_same_title_conference_does_not_replace_thesis(self):
        row=dict(kind='D',citations=[dict(raw='Putty, A Micromachined Vibrating Ring Gyroscope, Ph.D. thesis, 1995')])
        self.assertIsNotNone(a.compatibility_error(row,dict(type='proceedings-article',year=1994)))

    def test_online_and_issue_year_may_differ_by_one(self):
        row=dict(kind='J',citations=[dict(raw='Gyroscope paper. Journal, 2020.')])
        self.assertIsNone(a.compatibility_error(row,dict(type='journal-article',year=2021)))

    def test_html_is_not_pdf(self):
        with self.assertRaisesRegex(ValueError,'Not PDF'):
            a.pdf_check(b'<html>Download PDF</html>',dict(title='Test article'))

    def test_contents_are_not_fulltext(self):
        with patch.object(a,'PdfReader',return_value=Reader(['CONTENTS\nCoriolis Vibratory Gyros\nD D Lynch','Meeting contents'])):
            with self.assertRaisesRegex(ValueError,'Contents-only'):
                a.pdf_check(b'%PDF mock',dict(title='Coriolis Vibratory Gyros'))

    def test_doi_in_reference_is_not_article_identity(self):
        with patch.object(a,'PdfReader',return_value=Reader(['Different article entirely','References: 10.1109/example.1995.12345'])):
            with self.assertRaisesRegex(ValueError,'identity not verified'):
                a.pdf_check(b'%PDF mock',dict(title='Vibratory gyro analysis by the method of averaging',doi='10.1109/example.1995.12345'))

    def test_valid_first_page_identifier(self):
        with patch.object(a,'PdfReader',return_value=Reader(['Article heading 10.1109/example.1995.12345','Full article second page'])):
            check=a.pdf_check(b'%PDF mock',dict(title='Vibratory gyro analysis by the method of averaging',doi='10.1109/example.1995.12345'))
        self.assertEqual(check['identity'],'doi')
        self.assertEqual(check['pages'],2)

    def test_one_page_metadata_not_automatically_fulltext(self):
        with patch.object(a,'PdfReader',return_value=Reader(['Coriolis Vibratory Gyros'])):
            with self.assertRaisesRegex(ValueError,'One-page'):
                a.pdf_check(b'%PDF mock',dict(title='Coriolis Vibratory Gyros'))

    def test_atomic_progress_write(self):
        base=a.WORK/'verification_tmp';base.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=base) as t:
            p=Path(t)/'register.json'
            a.save(p,{'version':1,'title':'全角陀螺'})
            a.save(p,{'version':2,'title':'引用关系'})
            self.assertEqual(json.loads(p.read_text(encoding='utf-8')),{'version':2,'title':'引用关系'})
            self.assertFalse(list(Path(t).glob('*.tmp')))


if __name__=='__main__':unittest.main()
