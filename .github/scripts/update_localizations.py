import argparse
import json
import sys
import os


assert os.environ["OPENAI_API_KEY"] is not None


def main(file_path):
    print(file_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update Localizable.xcstrings based on git diff')
    parser.add_argument('file_path', help='Path to the Localizable.xcstrings file')
    args = parser.parse_args()

    main(args.file_path)
