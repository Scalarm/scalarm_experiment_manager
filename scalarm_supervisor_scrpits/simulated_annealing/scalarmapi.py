import json
import math
import requests
from requests.auth import HTTPBasicAuth
from requests.exceptions import Timeout
import time

f1 = lambda x: (4 - 2.1 * x[0] ** 2 + (x[0] ** 4) / 3) * x[0] ** 2 + x[0] * x[1] + (-4 + 4 * x[1] ** 2) * x[1] ** 2

f2 = lambda x: math.e + 20 - 20 * math.exp(-0.2 * math.sqrt(0.5 * (x[0] ** 2 + x[1] ** 2))) \
               - math.exp(0.5 * (math.cos(2 * math.pi * x[0]) + math.cos(2 * math.pi * x[1])))


class Scalarm:
    def __init__(self, user, password, experiment_id, address, parameters_ids):
        self.user = user
        self.password = password
        self.experiment_id = experiment_id
        self.address = address
        self.parameters_ids = parameters_ids

    def schedule_point(self, params):
        params_dict = {}
        for id, param in zip(self.parameters_ids, params):
            params_dict[id] = param
        print json.dumps(params_dict)
        r = requests.post("%s/experiments/%s/schedule_point.json" % (self.address, self.experiment_id),
                          auth=HTTPBasicAuth(self.user, self.password),
                          params={'point': json.dumps(params_dict)})
        print r.text

    def get_result(self, params):
        params_dict = {}
        for id, param in zip(self.parameters_ids, params):
            params_dict[id] = param
        while True:
            r = requests.get("%s/experiments/%s/get_result.json" % (self.address, self.experiment_id),
                             auth=HTTPBasicAuth(self.user, self.password),
                             params={'point': json.dumps(params_dict)})
            print r.text
            decoded_result = json.loads(r.text)
            if decoded_result["status"] == "error":
                print decoded_result["message"]
                time.sleep(1)
                continue
            elif decoded_result["status"] == "ok":
                return decoded_result["result"]["product"]

    def mark_as_complete(self):
        r = requests.post("%s/experiments/%s/mark_as_complete" % (self.address, self.experiment_id),
                          auth=HTTPBasicAuth(self.user, self.password))
        print r.text

    def set_result(self, result):
        r = requests.post("%s/experiments/%s/set_result.json" % (self.address, self.experiment_id),
                          auth=HTTPBasicAuth(self.user, self.password),
                          params={'result': json.dumps(result)})
        print r.text

