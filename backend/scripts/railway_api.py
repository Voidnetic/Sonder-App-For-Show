import json, sys, urllib.request, urllib.error
def gql(query, variables=None):
    req = urllib.request.Request("https://backboard.railway.com/graphql/v2",
        data=json.dumps({"query": query, "variables": variables or {}}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "sonder-deploy"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"http_error": e.code, "body": e.read().decode()[:500]}
PROJECT="566e5abe-4e08-446e-9858-5437c7e7037e"; ENV="eddd7895-9030-4a6b-befc-fdb5b5636dc0"
API="365256e7-b7bb-49fc-a2fc-c4e961cdb3da"; WS="44d68200-8904-40de-a920-28aeff8fd59d"
