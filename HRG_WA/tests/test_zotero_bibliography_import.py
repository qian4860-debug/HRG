import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from import_zotero_bibliography import prepare, make_item, match

class ImportTests(unittest.TestCase):
    def test_missing_titles_do_not_collapse(self):
        rows=[dict(id=str(i),title='标题不可用',author='A Author',year=2020,href='#') for i in range(3)]
        create,mapping=prepare(rows,[],'sha')
        self.assertEqual(len(create),3)
        self.assertEqual(len({r['key'] for r in mapping}),3)

    def test_source_replay_and_duplicate_rows(self):
        rows=[dict(id='a',title='A sufficiently specific paper',year=2020,href='https://example.org/article/1'),
              dict(id='b',title='A sufficiently specific paper',year=2020,href='https://example.org/article/1')]
        create,mapping=prepare(rows,[],'sha')
        self.assertEqual(len(create),1)
        self.assertEqual(mapping[0]['key'],mapping[1]['key'])
        again,_=prepare(rows,[dict(key='K',data=create[0])],'sha')
        self.assertEqual(again,[])

    def test_existing_rich_metadata_is_only_referenced(self):
        old=dict(key='K',version=3,data=dict(itemType='journalArticle',title='Specific scientific title',date='2020-05',DOI='10.1000/existing'))
        row=dict(id='x',title='Specific scientific title',year='2020',author='Y Wang…')
        create,mapping=prepare([row],[old],'sha')
        self.assertEqual(create,[])
        self.assertEqual(mapping[0]['key'],'K')
        self.assertEqual(old['data']['DOI'],'10.1000/existing')

    def test_different_known_years_are_not_title_only_duplicates(self):
        old=dict(key='K',data=dict(itemType='document',title='Specific scientific title',date='2020'))
        row=dict(id='x',title='Specific scientific title',year='2021')
        self.assertIsNone(match(row,[old],'sha')[0])

if __name__=='__main__':unittest.main()
