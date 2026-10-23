"""Offline regressions for citation direction and PDF identity gating."""
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import acquire_lynch1995_citing as acquisition


class CitationAcquisitionTests(unittest.TestCase):
    def test_record_id_alone_cannot_reuse_a_download_cache(self):
        prior={'requested_doi':'10.1/old','requested_title':'Old title'}
        self.assertFalse(acquisition.cache_matches(prior,{'doi':'10.1/new','title':'New title'}))
        self.assertFalse(acquisition.cache_matches({}, {'doi':None,'title':'New title'}))
        self.assertTrue(acquisition.cache_matches(prior,{'doi':'10.1/old','title':'Old title'}))

    def test_lynch_1998_is_not_a_1995_title_match(self):
        self.assertFalse(acquisition.match_citation('Lynch D. Coriolis vibratory gyros. 1998.'))
        self.assertTrue(acquisition.match_citation(
            'Lynch, D.D. Vibratory gyro analysis by the method of aver-\naging. 1995.'))

    def test_reference_list_match_does_not_identify_the_download(self):
        first='A completely different gyroscope article\nAbstract\nText cites Lynch and the requested title.'
        fake=SimpleNamespace(pages=[SimpleNamespace(extract_text=lambda:first)])
        with patch.object(acquisition.shared,'pdf_check',return_value={'identity':'doi'}), \
             patch.object(acquisition,'PdfReader',return_value=fake):
            with self.assertRaisesRegex(ValueError,'First-page title region'):
                acquisition.checked_pdf(b'%PDF',{'title':'Vibratory gyro analysis by the method of averaging'})

    def test_title_and_author_without_year_are_not_pdf_edge_evidence(self):
        text='Lynch D.D. Vibratory gyro analysis by the method of averaging. No publication year.'
        fake=SimpleNamespace(pages=[SimpleNamespace(extract_text=lambda:text)])
        with patch.object(acquisition,'PdfReader',return_value=fake):
            self.assertEqual(acquisition.citation_pages('unused'),[])

    def test_explicit_reference_creates_a_directed_edge(self):
        text='References\n17. Lynch D.D. Vibratory gyro analysis by the method of averaging. 1995, pp. 26-34.'
        fake=SimpleNamespace(pages=[SimpleNamespace(extract_text=lambda:text)])
        with patch.object(acquisition,'PdfReader',return_value=fake):
            result=acquisition.citation_pages('unused')
        self.assertEqual(result[0]['pdf_page'],1)
        self.assertEqual(result[0]['year'],1995)


if __name__=='__main__':unittest.main()
