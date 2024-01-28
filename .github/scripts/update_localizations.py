import argparse
import collections
import json
from openai import OpenAI
import os


assert os.environ["OPENAI_API_KEY"] is not None
openai_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])


def translate(string, language):
    response = openai_client.chat.completions.create(
        model='gpt-3.5-turbo-1106',
        messages=[
            {
                'role': 'system', 'content': 'You are a professional localizer, translating strings for a Swift application. Given an English string and a target language, you must translate the string to the target language and submit it for human validation.'
            },
            {
                'role': 'user', 'content': f'Translate to {language}:\n```{string}```'
            }
        ],
        tools=[
            {
                "function": {
                    "name": "validate_translation",
                    "description": "Submit translated string for human validation",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "target": {
                                "type": "string",
                                "description": "Auto-translated string"
                            }
                        }
                    },
                },
                "type": "function"
            }
        ],
        tool_choice={
            "function": {
                "name": "validate_translation"
            },
            "type": "function"
        }
    )

    return json.loads(response.choices[0].message.tool_calls[0].function.arguments)['target']


SUPPORTED_LANGUAGES = ['fr', 'it']


def main(file_path):
    with open(file_path, 'r') as f:
        localizable_strings = json.load(f, object_pairs_hook=collections.OrderedDict)

    ## handle changes
    missing_translations = {
        key: []
        for key in SUPPORTED_LANGUAGES
    }

    stale_keys = []

    for i, (key, value) in enumerate(localizable_strings['strings'].items()):
        if key == '':
            continue
        
        if 'extractionState' in value and value['extractionState'] == 'stale':
            stale_keys.append(key)
        elif 'localizations' not in value:
            for language in SUPPORTED_LANGUAGES:
                missing_translations[language].append(key)
    
    for stale_key in stale_keys:
        del localizable_strings['strings'][stale_key]

    for target, strings in missing_translations.items():
        for string in strings:
            translated = translate(target, string)
            if 'localizations' not in localizable_strings['strings'][string]:
                localizable_strings['strings'][string]['localizations'] = {}
            localizable_strings['strings'][string]['localizations'][target] = {
                "stringUnit" : {
                    "state" : "translated",
                    "value" : translated
                }
            }

    with open(file_path, 'w') as w:
        raw = json.dumps(localizable_strings, ensure_ascii=False, indent=2, separators=(',', ' : '))
        raw = raw.replace('{},\n', '{\n\n    },\n')  # overwrite if there's an empty dictionary
        w.write(raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update Localizable.xcstrings based on git diff')
    parser.add_argument('file_path', help='Path to the Localizable.xcstrings file')
    args = parser.parse_args()

    main(args.file_path)
