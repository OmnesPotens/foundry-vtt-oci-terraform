import requests_html
import getpass
import re
import argparse

parser = argparse.ArgumentParser(description="Read credentials file")
parser.add_argument(dest="file_path", metavar="file_path", default="", nargs='*')
args = parser.parse_args()

FVTT_URL = "https://foundryvtt.com"
LOGIN_URL = FVTT_URL + "/auth/login/"
LICENSES_URL = FVTT_URL + "/me/licenses"

try:
    have_args = args.file_path
    if have_args and len(args.file_path[0]) > 0:
        with open(args.file_path[0]) as f:
          file_contents = [line.rstrip('\n') for line in f]
          foundry_creds = file_contents[0].split(" ")
          username = foundry_creds[0]
          password = foundry_creds[1]
    else:
        username = getpass.getpass(prompt="Enter your Foundry username: ")
        password = getpass.getpass(prompt="Enter your Foundry password: ")
except Exception as error:
    print("ERROR", error)

headers = {
    "DNT": "1",
    "Referer": FVTT_URL,
    "Upgrade-Insecure-Requests": "1",
}


def get_csrfmiddlewaretoken(session):
    return (
        session.html.find("input[name=csrfmiddlewaretoken]")[0]
        .attrs["value"]
        .strip("'")
    )


def login_to_fvtt(session):
    print("Logging into " + FVTT_URL)
    r = session.get(FVTT_URL, headers=headers)
    # get csrfmiddlewaretoken for login
    csrfmiddlewaretoken = get_csrfmiddlewaretoken(r)
    payload = {
        "csrfmiddlewaretoken": csrfmiddlewaretoken,
        "login_username": username,
        "login_password": password,
        "login_redirect": "/",
        "login": "",
    }
    # login
    return session.post(LOGIN_URL, data=payload, headers=headers)


def get_recommended_build(session):
    print("Getting Recommended Releases")
    licenses = session.get(LICENSES_URL, headers=headers)
    # print(licenses.html.find('optgroup[label="Recommended Releases"]'))
    return licenses.html.find('optgroup[label="Recommended Releases"]')[0].find(
        "option"
    )[0]


def get_build_text(html):
    return html.text.strip("'")


def get_build_number(html):
    return html.attrs["value"].strip("'")


def get_build_version(build_text):
    return re.search(r"\d+\.\d+", build_text).group()


def get_s3_url(session, build_number):
    print("Getting download URL")
    RELEASE_URL = "{}/releases/download?build={}&platform=linux".format(
        FVTT_URL, build_number
    )
    return session.get(RELEASE_URL, headers=headers).html.url


def download_url(session, save_path, chunk_size=128):
    print("Downloading to: " + save_path)
    with open(save_path, "wb") as fd:
        for chunk in session.iter_content(chunk_size=chunk_size):
            fd.write(chunk)


with requests_html.HTMLSession() as s:
    s = requests_html.HTMLSession()
    p = login_to_fvtt(s)
    # print(p)
    recommended_build = get_recommended_build(s)
    build_text = get_build_text(recommended_build)
    build_number = get_build_number(recommended_build)
    build_version = get_build_version(build_text)
    S3_URL = get_s3_url(s, build_number)
    latest_release = s.get(S3_URL, stream=True)
    file_path = "./FoundryVTT-{}.zip".format(build_version)
    download_url(latest_release, file_path)
    print("END")
