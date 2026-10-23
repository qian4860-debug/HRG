"""Preflight guards must fail before a local Zotero write can occur."""
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import zotero_wa_bridge as bridge
TEST_TEMP=bridge.WORK/'test_tmp'
TEST_TEMP.mkdir(parents=True,exist_ok=True)


class ZoteroBridgeGuards(unittest.TestCase):
    def test_different_server_stops_before_writes(self):
        with patch.object(bridge,'read',return_value={'server':'database-a'}), \
             patch.object(bridge,'LocalAPI') as api, \
             patch.object(bridge,'inventory',return_value={'server':'database-b'}):
            with self.assertRaisesRegex(RuntimeError,'Different Zotero database'):bridge.apply()
            api.return_value.write_many.assert_not_called()

    def test_changed_source_stops_before_writes(self):
        with tempfile.TemporaryDirectory(dir=TEST_TEMP) as folder:
            p=Path(folder)/'paper.pdf';p.write_bytes(b'new bytes')
            requested={'server':'same','source_files':[{'path':str(p),'sha256':'old-hash'}]}
            current={'server':'same','files':[],'items':[]}
            with patch.object(bridge,'read',return_value=requested),patch.object(bridge,'LocalAPI') as api, \
                 patch.object(bridge,'inventory',return_value=current):
                with self.assertRaisesRegex(RuntimeError,'Source changed'):bridge.apply()
                api.return_value.write_many.assert_not_called()

    def test_identical_files_only_need_one_link(self):
        with tempfile.TemporaryDirectory(dir=TEST_TEMP) as folder:
            root=Path(folder);(root/'one.pdf').write_bytes(b'same');(root/'two.pdf').write_bytes(b'same')
            (root/'unrelated.m').write_text('ignored')
            with patch.object(bridge,'HEAD',root):plan=bridge.source_files()
            self.assertEqual(len(plan),1)
            self.assertEqual(len(plan[0]['other_paths']),1)


if __name__=='__main__':unittest.main()
