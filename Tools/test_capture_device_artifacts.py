import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from capture_device_artifacts import artifact_paths, capture


def entry(path, **resources):
    return {"relativePath": path, "resources": resources}


class CaptureArtifactsTests(unittest.TestCase):
    def test_downloads_only_images_and_json_as_individual_files(self):
        entries = [entry("review/screen.png"), entry("review/result.json"),
                   entry("content.sqlite"), entry("content.sqlite-wal"),
                   entry("review", isDirectory=True), entry("link.png", isSymbolicLink=True)]
        with tempfile.TemporaryDirectory() as output, patch("capture_device_artifacts.subprocess.run") as run:
            run.return_value.stdout = json.dumps({"result": {"files": entries}})
            capture("device", "app", Path(output))
            self.assertEqual(run.call_count, 3)
            sources = [call.args[0][call.args[0].index("--source") + 1]
                       for call in run.call_args_list[1:]]
            self.assertEqual(sources, ["Documents/review/screen.png", "Documents/review/result.json"])

    def test_rejects_paths_outside_the_requested_directory(self):
        for path in ["/outside.png", "../outside.json", "review/../../outside.png"]:
            with self.assertRaises(ValueError):
                list(artifact_paths([entry(path)]))


if __name__ == "__main__":
    unittest.main()
