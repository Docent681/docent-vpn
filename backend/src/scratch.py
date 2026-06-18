import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

r = requests.get("https://109.120.178.97:55175/9cFR79qGurakTyvBGk8KQQ/server", verify=False)
print(r.content)
