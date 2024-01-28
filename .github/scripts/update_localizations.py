import argparse
import collections
import json
import os


assert os.environ["OPENAI_API_KEY"] is not None


def main(file_path):
    with open(file_path, 'r') as f:
        strings = json.load(f, object_pairs_hook=collections.OrderedDict)

    ## handle changes
    stale_keys = []
    for i, (key, value) in enumerate(strings['strings'].items()):
        if 'extractionState' in value and value['extractionState'] == 'stale':
            stale_keys.append(key)

    for key in stale_keys:
        del strings['strings'][key]
    ## 

    with open(file_path, 'w') as w:
        raw = json.dumps(strings, ensure_ascii=False, indent=2, separators=(',', ' : '))
        raw = raw.replace('{},\n', '{\n\n    },\n')  # overwrite if there's an empty dictionary
        w.write(raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update Localizable.xcstrings based on git diff')
    parser.add_argument('file_path', help='Path to the Localizable.xcstrings file')
    args = parser.parse_args()

    main(args.file_path)
